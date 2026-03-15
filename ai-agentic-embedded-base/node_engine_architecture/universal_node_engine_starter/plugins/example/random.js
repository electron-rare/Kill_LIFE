import { register } from "../../engine/registry.js"

register({
    type:"random",
    outputs:["value"],
    run(){
        return { value: Math.random() }
    }
})
