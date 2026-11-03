// Command jsonschema-testrunner runs the JSON Schema Test Suite against the
// XSD 1.1 schemas compiled by xslt/json-schema-to-xsd.xslt.
//
// For every test file test-NN.xml in the XML tree (test-suites/json-schema-xml)
// it takes the test's data as an instance document, validates it with go-xslt
// against schema.xsd of the same group in the XSD tree
// (test-suites/json-schema-xsd) and compares the verdict with the test's
// "valid". It prints a summary per test directory and exits with status 1 if
// any test fails.
//
// The tests can be in the W3C representation of fn:json-to-xml
// (test-suites/json-schema-xml, the default) or in the JSON elements format
// of xslt/json-elements.xslt (test-suites/json-schema-elements, with -format
// elements).
//
// Usage, from the repository root:
//
//	go run ./tools/jsonschema-testrunner
//	go run ./tools/jsonschema-testrunner -format elements
//	go run ./tools/jsonschema-testrunner -filter draft2020-12/ref -v
//	go run ./tools/jsonschema-testrunner -failures failures.txt
//	go run ./tools/jsonschema-testrunner -known test-suites/known-failures.json
//
// With -known, failures listed in the JSON file are expected: the exit status
// is 1 only for a failure that is not listed, or for a listed test that
// passes (so that the list stays accurate).
package main

import (
	"cmp"
	"encoding/json"
	"flag"
	"fmt"
	"io/fs"
	"os"
	"path/filepath"
	"runtime"
	"sort"
	"strings"
	"sync"

	"github.com/tim-riep/go-xslt/engine"
)

// extract writes "valid|<data as a standalone document>" for a test-NN.xml,
// in the W3C representation of fn:json-to-xml (a map with members keyed by
// @key) or in the JSON elements format (a json element with members as
// elements, where the data becomes a json element of its own).
const extract = `<xsl:stylesheet version="3.0" xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
    xmlns:fn="http://www.w3.org/2005/xpath-functions">
  <xsl:output method="xml" omit-xml-declaration="yes"/>
  <xsl:template match="/fn:map">
    <xsl:value-of select="normalize-space(fn:boolean[@key = 'valid'])"/>
    <xsl:text>|</xsl:text>
    <xsl:for-each select="*[@key = 'data']">
      <xsl:copy>
        <xsl:copy-of select="@* except (@key, @escaped-key), node()"/>
      </xsl:copy>
    </xsl:for-each>
  </xsl:template>
  <xsl:template match="/json">
    <xsl:value-of select="normalize-space(valid)"/>
    <xsl:text>|</xsl:text>
    <xsl:for-each select="data">
      <json>
        <xsl:copy-of select="@*, node()"/>
      </json>
    </xsl:for-each>
  </xsl:template>
</xsl:stylesheet>`

type result struct {
	path   string // relative to the XML tree, e.g. tests/draft7/type/01/test-01.xml
	passed bool
	detail string
}

func main() {
	format := flag.String("format", "xpath", "XML representation of the tests: xpath or elements (sets the defaults of -xml and -xsd)")
	xmlRoot := flag.String("xml", "", "directory of the tests as XML (schema.xml, test-NN.xml); default test-suites/json-schema-xml or test-suites/json-schema-elements")
	xsdRoot := flag.String("xsd", "", "directory of the compiled schemas (schema.xsd); default test-suites/json-schema-xsd or test-suites/json-schema-elements-xsd")
	filter := flag.String("filter", "", "run only tests whose path contains this text")
	failures := flag.String("failures", "", "write the failed tests to this file")
	verbose := flag.Bool("v", false, "print every failed test")
	workers := flag.Int("j", runtime.NumCPU(), "number of tests run in parallel")
	knownFile := flag.String("known", "", "JSON file with the expected failures ({\"failures\": [{\"test\": path, \"reason\": text}]})")
	flag.Parse()
	switch *format {
	case "xpath":
		*xmlRoot = cmp.Or(*xmlRoot, "test-suites/json-schema-xml")
		*xsdRoot = cmp.Or(*xsdRoot, "test-suites/json-schema-xsd")
	case "elements":
		*xmlRoot = cmp.Or(*xmlRoot, "test-suites/json-schema-elements")
		*xsdRoot = cmp.Or(*xsdRoot, "test-suites/json-schema-elements-xsd")
	default:
		fmt.Fprintln(os.Stderr, "jsonschema-testrunner: -format must be xpath or elements")
		os.Exit(2)
	}

	sheet, diags := engine.Compile(engine.Request{Stylesheet: extract})
	if sheet == nil {
		fmt.Fprintln(os.Stderr, "jsonschema-testrunner: cannot compile the extraction stylesheet:", diags)
		os.Exit(2)
	}

	tests, err := findTests(*xmlRoot, *filter)
	if err != nil {
		fmt.Fprintln(os.Stderr, "jsonschema-testrunner:", err)
		os.Exit(2)
	}
	if len(tests) == 0 {
		fmt.Fprintln(os.Stderr, "jsonschema-testrunner: no tests found in", *xmlRoot)
		os.Exit(2)
	}

	results := make([]result, len(tests))
	var wg sync.WaitGroup
	sem := make(chan struct{}, max(*workers, 1))
	for i, t := range tests {
		wg.Add(1)
		sem <- struct{}{}
		go func() {
			defer wg.Done()
			defer func() { <-sem }()
			results[i] = run(sheet, *xmlRoot, *xsdRoot, t)
		}()
	}
	wg.Wait()

	failed := report(results, *verbose)
	if *failures != "" {
		if err := writeFailures(*failures, results); err != nil {
			fmt.Fprintln(os.Stderr, "jsonschema-testrunner:", err)
			os.Exit(2)
		}
	}
	if *knownFile == "" {
		if failed > 0 {
			os.Exit(1)
		}
		return
	}
	known, err := readKnown(*knownFile)
	if err != nil {
		fmt.Fprintln(os.Stderr, "jsonschema-testrunner:", err)
		os.Exit(2)
	}
	if !checkKnown(results, known) {
		os.Exit(1)
	}
}

// readKnown reads the expected failures: test path to reason.
func readKnown(name string) (map[string]string, error) {
	data, err := os.ReadFile(name)
	if err != nil {
		return nil, err
	}
	var file struct {
		Failures []struct {
			Test   string `json:"test"`
			Reason string `json:"reason"`
		} `json:"failures"`
	}
	if err := json.Unmarshal(data, &file); err != nil {
		return nil, fmt.Errorf("%s: %w", name, err)
	}
	known := map[string]string{}
	for _, f := range file.Failures {
		known[f.Test] = f.Reason
	}
	return known, nil
}

// checkKnown compares the results with the expected failures and reports
// unexpected failures and expected failures that pass. Expected failures of
// tests that were not run (-filter) are ignored.
func checkKnown(results []result, known map[string]string) bool {
	ok := true
	for _, r := range results {
		reason, expected := known[r.path]
		switch {
		case !r.passed && !expected:
			fmt.Printf("UNEXPECTED FAILURE %s: %s\n", r.path, r.detail)
			ok = false
		case r.passed && expected:
			fmt.Printf("UNEXPECTED PASS %s (listed as a known failure: %s)\n", r.path, reason)
			ok = false
		}
	}
	if ok {
		failed := 0
		for _, r := range results {
			if !r.passed {
				failed++
			}
		}
		if failed == 0 {
			fmt.Println("all tests pass")
		} else {
			fmt.Println("all failures are known failures")
		}
	}
	return ok
}

// findTests returns the paths of all test-NN.xml files below root/tests,
// relative to root, in name order.
func findTests(root, filter string) ([]string, error) {
	var tests []string
	err := filepath.WalkDir(filepath.Join(root, "tests"), func(p string, d fs.DirEntry, err error) error {
		if err != nil {
			return err
		}
		if d.IsDir() || !strings.HasPrefix(d.Name(), "test-") || !strings.HasSuffix(d.Name(), ".xml") {
			return nil
		}
		rel, err := filepath.Rel(root, p)
		if err != nil {
			return err
		}
		rel = filepath.ToSlash(rel)
		if strings.Contains(rel, filter) {
			tests = append(tests, rel)
		}
		return nil
	})
	sort.Strings(tests)
	return tests, err
}

// run validates the data of one test against its group's schema.
func run(sheet *engine.Stylesheet, xmlRoot, xsdRoot, rel string) result {
	src, err := os.ReadFile(filepath.Join(xmlRoot, rel))
	if err != nil {
		return result{rel, false, err.Error()}
	}
	out := sheet.Transform(engine.TransformRequest{Source: string(src)})
	if out.HasErrors() {
		return result{rel, false, fmt.Sprint("cannot read the test: ", out.Diagnostics)}
	}
	expected, data, ok := strings.Cut(out.Output, "|")
	if !ok || (expected != "true" && expected != "false") {
		return result{rel, false, "the test has no boolean valid"}
	}
	xsdPath := filepath.Join(xsdRoot, filepath.Dir(rel), "schema.xsd")
	xsd, err := os.ReadFile(xsdPath)
	if err != nil {
		return result{rel, false, "no compiled schema: " + xsdPath}
	}
	// The schema may include others (remote schemas, generic types) by
	// relative location anywhere below the XSD tree.
	v := engine.Validate(engine.ValidateRequest{
		Schemas:  []string{string(xsd)},
		Instance: data,
		Version:  engine.XSD11,
		BaseDir:  filepath.Dir(xsdPath),
		Security: engine.Security{AllowedDirs: []string{xsdRoot}},
	})
	if v.Valid == (expected == "true") {
		return result{rel, true, ""}
	}
	var msgs []string
	for _, d := range v.Diagnostics {
		msgs = append(msgs, d.Message)
	}
	detail := fmt.Sprintf("expected valid=%s, got valid=%v", expected, v.Valid)
	if len(msgs) > 0 {
		detail += ": " + strings.Join(msgs, "; ")
	}
	return result{rel, false, detail}
}

// group is the line of the summary a test counts in: the dialect, plus
// "/optional" for the optional tests.
func group(rel string) string {
	parts := strings.Split(rel, "/")
	if len(parts) < 3 {
		return rel
	}
	if parts[2] == "optional" {
		return parts[1] + "/optional"
	}
	return parts[1]
}

func report(results []result, verbose bool) int {
	type count struct{ passed, total int }
	counts := map[string]*count{}
	failed := 0
	for _, r := range results {
		g := group(r.path)
		if counts[g] == nil {
			counts[g] = &count{}
		}
		counts[g].total++
		if r.passed {
			counts[g].passed++
			continue
		}
		failed++
		if verbose {
			fmt.Printf("FAIL %s: %s\n", r.path, r.detail)
		}
	}
	groups := make([]string, 0, len(counts))
	for g := range counts {
		groups = append(groups, g)
	}
	sort.Strings(groups)
	line := func(name string, c count) {
		fmt.Printf("%-24s %6d / %6d  %5.1f%%\n", name, c.passed, c.total, 100*float64(c.passed)/float64(c.total))
	}
	var total count
	for _, g := range groups {
		c := *counts[g]
		line(g, c)
		total.passed += c.passed
		total.total += c.total
	}
	line("total", total)
	return failed
}

func writeFailures(name string, results []result) error {
	var b strings.Builder
	for _, r := range results {
		if !r.passed {
			fmt.Fprintf(&b, "%s: %s\n", r.path, r.detail)
		}
	}
	return os.WriteFile(name, []byte(b.String()), 0o644)
}
