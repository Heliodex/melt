import { Elysia } from "elysia"

const app = new Elysia().get("/", () => "Hello World!").listen(2013)

console.log(`Serving at http://${app.server?.hostname}:${app.server?.port}`)
