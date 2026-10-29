// autoclaw-relay.mjs — chuyển tiếp cổng login AutoClaw ra ngoài mà bỏ Origin/Referer,
// để guide page gọi được /captcha và /open-auth (plugin chỉ nhận Origin localhost).
import http from "node:http"

const LISTEN = Number(process.env.RELAY_PORT || 18080)
const TARGET_HOST = "127.0.0.1"
const TARGET_PORT = Number(process.env.LOGIN_PORT || 18432)

http.createServer((req, res) => {
  const headers = { ...req.headers }
  delete headers.origin
  delete headers.referer
  delete headers.host
  const up = http.request(
    { host: TARGET_HOST, port: TARGET_PORT, method: req.method, path: req.url, headers },
    (r) => { res.writeHead(r.statusCode || 502, r.headers); r.pipe(res) },
  )
  up.on("error", () => {
    res.writeHead(502, { "Content-Type": "text/plain; charset=utf-8" })
    res.end("phiên đăng nhập AutoClaw chưa mở (cổng " + TARGET_PORT + ")")
  })
  req.pipe(up)
}).listen(LISTEN, "127.0.0.1", () => {
  console.log(`relay ${LISTEN} -> ${TARGET_HOST}:${TARGET_PORT}`)
})
