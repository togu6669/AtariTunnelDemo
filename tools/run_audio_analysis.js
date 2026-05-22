import { spawn } from "node:child_process";
import path from "node:path";
import { fileURLToPath } from "node:url";

const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);
const root = path.resolve(__dirname, "..");
const chrome = "C:\\Program Files (x86)\\Google\\Chrome\\Application\\chrome.exe";
const port = 9223;
const pageUrl = "file:///F:/Prog/Atari/Demo/tools/analyze_audio.html";

function sleep(ms) {
  return new Promise((resolve) => setTimeout(resolve, ms));
}

async function getPage() {
  for (let i = 0; i < 30; i++) {
    try {
      const pages = await (await fetch(`http://127.0.0.1:${port}/json`)).json();
      const page = pages.find((item) => item.type === "page" && item.url.includes("analyze_audio.html"));
      if (page) return page;
    } catch {
      // Chrome is still starting.
    }
    await sleep(250);
  }
  throw new Error("Chrome debugging page did not appear");
}

function cdpEval(wsUrl, expression) {
  return new Promise((resolve, reject) => {
    const ws = new WebSocket(wsUrl);
    const id = 1;
    ws.addEventListener("open", () => {
      ws.send(JSON.stringify({
        id,
        method: "Runtime.evaluate",
        params: { expression, returnByValue: true },
      }));
    });
    ws.addEventListener("message", (event) => {
      const msg = JSON.parse(event.data);
      if (msg.id !== id) return;
      ws.close();
      if (msg.error) reject(new Error(JSON.stringify(msg.error)));
      else resolve(msg.result.result.value);
    });
    ws.addEventListener("error", reject);
  });
}

const child = spawn(chrome, [
  "--headless=new",
  "--no-sandbox",
  "--disable-gpu",
  "--allow-file-access-from-files",
  `--remote-debugging-port=${port}`,
  `--user-data-dir=${path.join(root, "chrome-profile-rmt")}`,
  pageUrl,
], { stdio: "ignore" });

try {
  const page = await getPage();
  let text = "";
  for (let i = 0; i < 40; i++) {
    text = await cdpEval(page.webSocketDebuggerUrl, "document.getElementById('out').textContent");
    if (text && text !== "working") break;
    await sleep(500);
  }
  console.log(text);
} finally {
  child.kill();
}
