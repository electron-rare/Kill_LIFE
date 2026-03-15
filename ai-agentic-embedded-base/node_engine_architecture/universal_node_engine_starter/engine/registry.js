export const registry = {}

export function register(node){
    registry[node.type] = node
}
