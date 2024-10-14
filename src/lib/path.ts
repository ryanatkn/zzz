// TODO refactor, can't import `to_base_path` at the moment on the client
export const to_base_path = (path: string) => '/src/' + path.split('/src/')[1];
