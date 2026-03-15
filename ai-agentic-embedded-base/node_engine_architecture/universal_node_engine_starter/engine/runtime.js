import { registry } from "./registry.js"
import "../plugins/example/random.js"

export async function runGraph(graph){

    for(const node of graph.nodes){

        const nodeDef = registry[node.type]

        if(!nodeDef){
            console.error("Unknown node:", node.type)
            continue
        }

        const inputs = {}

        const outputs = await nodeDef.run(node, inputs)

        console.log("Node output:", outputs)

    }
}

const demoGraph = {
    nodes:[
        { id:"rand1", type:"random" }
    ]
}

runGraph(demoGraph)
