# Plugin API

## Plugin Structure

plugin_name/

nodes/  
runtime/  
ui/  
plugin.json  

---

## plugin.json

{
  "name": "example_plugin",
  "version": "1.0",
  "nodes": ["example_node"]
}

---

## Node Definition

registry.register({
  type: "example_node",
  inputs: ["in"],
  outputs: ["out"],
  run(node, inputs) {
    return { out: inputs.in }
  }
})

---

## Async Node

async run(node, inputs) {
  const result = await fetch("/api")
  return { output: result }
}

---

Plugins peuvent ajouter nodes, UI widgets et logique runtime.
