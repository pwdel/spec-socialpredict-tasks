#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'EOF'
Usage: query_openapi.sh <repo-dir> <command> [args]

Commands:
  summary
  tags
  tag <tag-name>
  path <path-key>
  operation <path-key> <method>
  schema <schema-name>
  refs <schema-name>
EOF
}

if [ "$#" -lt 2 ]; then
  usage
  exit 1
fi

REPO_DIR="$1"
shift

COMMAND="$1"
shift

BACKEND_DIR="$REPO_DIR/backend"
SPEC_PATH="$BACKEND_DIR/docs/openapi.yaml"

if [ ! -d "$BACKEND_DIR" ]; then
  echo "Expected backend directory at $BACKEND_DIR" >&2
  exit 1
fi

if [ ! -f "$SPEC_PATH" ]; then
  echo "Expected OpenAPI spec at $SPEC_PATH" >&2
  exit 1
fi

if [ ! -f "$BACKEND_DIR/go.mod" ]; then
  echo "Expected Go module at $BACKEND_DIR/go.mod" >&2
  exit 1
fi

TMP_ROOT="${TMPDIR:-/tmp}/socialpredict-openapi-navigation"
mkdir -p "$TMP_ROOT"

GO_CACHE_DIR="$TMP_ROOT/gocache"
GO_MOD_CACHE_DIR="$TMP_ROOT/gomodcache"
mkdir -p "$GO_CACHE_DIR" "$GO_MOD_CACHE_DIR"

TMP_GO="$(mktemp "$TMP_ROOT/query-XXXX.go")"
cleanup() {
  rm -f "$TMP_GO"
}
trap cleanup EXIT

cat >"$TMP_GO" <<'EOF'
package main

import (
	"encoding/json"
	"fmt"
	"os"
	"sort"
	"strings"

	"gopkg.in/yaml.v3"
)

type OpenAPI struct {
	Tags       []Tag                          `yaml:"tags"`
	Paths      map[string]map[string]any      `yaml:"paths"`
	Components struct{ Schemas map[string]any `yaml:"schemas"` } `yaml:"components"`
}

type Tag struct {
	Name        string `yaml:"name"`
	Description string `yaml:"description"`
}

var httpMethods = map[string]bool{
	"get":     true,
	"post":    true,
	"put":     true,
	"patch":   true,
	"delete":  true,
	"options": true,
	"head":    true,
	"trace":   true,
}

func fail(format string, args ...any) {
	fmt.Fprintf(os.Stderr, format+"\n", args...)
	os.Exit(1)
}

func printJSON(v any) {
	data, err := json.MarshalIndent(v, "", "  ")
	if err != nil {
		fail("json encode: %v", err)
	}
	fmt.Println(string(data))
}

func loadSpec(path string) *OpenAPI {
	data, err := os.ReadFile(path)
	if err != nil {
		fail("read spec: %v", err)
	}

	var spec OpenAPI
	if err := yaml.Unmarshal(data, &spec); err != nil {
		fail("parse yaml: %v", err)
	}

	if spec.Paths == nil {
		spec.Paths = map[string]map[string]any{}
	}
	if spec.Components.Schemas == nil {
		spec.Components.Schemas = map[string]any{}
	}

	return &spec
}

func sortedPathKeys(paths map[string]map[string]any) []string {
	keys := make([]string, 0, len(paths))
	for key := range paths {
		keys = append(keys, key)
	}
	sort.Strings(keys)
	return keys
}

func sortedMapKeys(m map[string]any) []string {
	keys := make([]string, 0, len(m))
	for key := range m {
		keys = append(keys, key)
	}
	sort.Strings(keys)
	return keys
}

func operationCount(spec *OpenAPI) int {
	count := 0
	for _, pathItem := range spec.Paths {
		for method := range pathItem {
			if httpMethods[strings.ToLower(method)] {
				count++
			}
		}
	}
	return count
}

func operationTags(op map[string]any) []string {
	raw, ok := op["tags"]
	if !ok {
		return nil
	}
	items, ok := raw.([]any)
	if !ok {
		return nil
	}
	out := make([]string, 0, len(items))
	for _, item := range items {
		if s, ok := item.(string); ok {
			out = append(out, s)
		}
	}
	return out
}

func matchesTag(op map[string]any, want string) bool {
	for _, tag := range operationTags(op) {
		if tag == want {
			return true
		}
	}
	return false
}

func tagOperations(spec *OpenAPI, want string) []map[string]any {
	var ops []map[string]any
	for _, path := range sortedPathKeys(spec.Paths) {
		pathItem := spec.Paths[path]
		for _, method := range sortedMapKeys(pathItem) {
			if !httpMethods[strings.ToLower(method)] {
				continue
			}
			raw := pathItem[method]
			op, ok := raw.(map[string]any)
			if !ok || !matchesTag(op, want) {
				continue
			}

			summary, _ := op["summary"].(string)
			ops = append(ops, map[string]any{
				"method":  strings.ToUpper(method),
				"path":    path,
				"summary": summary,
			})
		}
	}
	return ops
}

func countTagOperations(spec *OpenAPI, want string) int {
	return len(tagOperations(spec, want))
}

func escapeJSONPointerToken(s string) string {
	s = strings.ReplaceAll(s, "~", "~0")
	s = strings.ReplaceAll(s, "/", "~1")
	return s
}

func findSchemaRefs(v any, targetRef string, pointer string, matches *[]string) {
	switch node := v.(type) {
	case map[string]any:
		keys := make([]string, 0, len(node))
		for key := range node {
			keys = append(keys, key)
		}
		sort.Strings(keys)
		for _, key := range keys {
			next := pointer + "/" + escapeJSONPointerToken(key)
			value := node[key]
			if key == "$ref" {
				if ref, ok := value.(string); ok && ref == targetRef {
					*matches = append(*matches, next)
				}
			}
			findSchemaRefs(value, targetRef, next, matches)
		}
	case []any:
		for i, value := range node {
			findSchemaRefs(value, targetRef, fmt.Sprintf("%s/%d", pointer, i), matches)
		}
	}
}

func main() {
	if len(os.Args) < 3 {
		fail("usage: <spec-path> <command> [args]")
	}

	specPath := os.Args[1]
	command := os.Args[2]
	args := os.Args[3:]

	spec := loadSpec(specPath)

	switch command {
	case "summary":
		tagSummaries := make([]map[string]any, 0, len(spec.Tags))
		for _, tag := range spec.Tags {
			tagSummaries = append(tagSummaries, map[string]any{
				"name":            tag.Name,
				"description":     tag.Description,
				"operation_count": countTagOperations(spec, tag.Name),
			})
		}
		printJSON(map[string]any{
			"spec_path":        specPath,
			"path_count":       len(spec.Paths),
			"operation_count":  operationCount(spec),
			"schema_count":     len(spec.Components.Schemas),
			"tag_count":        len(spec.Tags),
			"tags":             tagSummaries,
		})
	case "tags":
		tagSummaries := make([]map[string]any, 0, len(spec.Tags))
		for _, tag := range spec.Tags {
			tagSummaries = append(tagSummaries, map[string]any{
				"name":            tag.Name,
				"description":     tag.Description,
				"operation_count": countTagOperations(spec, tag.Name),
			})
		}
		printJSON(tagSummaries)
	case "tag":
		if len(args) != 1 {
			fail("tag requires exactly 1 argument")
		}
		printJSON(map[string]any{
			"tag":        args[0],
			"operations": tagOperations(spec, args[0]),
		})
	case "path":
		if len(args) != 1 {
			fail("path requires exactly 1 argument")
		}
		pathItem, ok := spec.Paths[args[0]]
		if !ok {
			fail("path not found: %s", args[0])
		}
		printJSON(pathItem)
	case "operation":
		if len(args) != 2 {
			fail("operation requires exactly 2 arguments")
		}
		pathItem, ok := spec.Paths[args[0]]
		if !ok {
			fail("path not found: %s", args[0])
		}
		method := strings.ToLower(args[1])
		raw, ok := pathItem[method]
		if !ok {
			fail("operation not found: %s %s", strings.ToUpper(method), args[0])
		}
		printJSON(raw)
	case "schema":
		if len(args) != 1 {
			fail("schema requires exactly 1 argument")
		}
		schema, ok := spec.Components.Schemas[args[0]]
		if !ok {
			fail("schema not found: %s", args[0])
		}
		printJSON(schema)
	case "refs":
		if len(args) != 1 {
			fail("refs requires exactly 1 argument")
		}
		targetRef := "#/components/schemas/" + args[0]
		matches := []string{}
		for _, path := range sortedPathKeys(spec.Paths) {
			findSchemaRefs(spec.Paths[path], targetRef, "/paths/"+escapeJSONPointerToken(path), &matches)
		}
		findSchemaRefs(spec.Components.Schemas, targetRef, "/components/schemas", &matches)
		sort.Strings(matches)
		printJSON(map[string]any{
			"schema":  args[0],
			"target":  targetRef,
			"matches": matches,
		})
	default:
		fail("unknown command: %s", command)
	}
}
EOF

(
  cd "$BACKEND_DIR"
  GOMODCACHE="$GO_MOD_CACHE_DIR" GOCACHE="$GO_CACHE_DIR" go run "$TMP_GO" "$SPEC_PATH" "$COMMAND" "$@"
)
