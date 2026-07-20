#!/usr/bin/env bash
# ANDRAX 2.0 — Web UI Emulator / Browser Tester
# This is a development utility that creates a simple web interface
# to test the ANDRAX backend without needing an Android device.
#
# It serves:
#   1. An interactive HTML UI (browser-based tool catalog)
#   2. REST API endpoints for tool/workflow execution
#   3. WebSocket connections for streaming output (optional)
#
# USAGE:
#   bash tools/web-tester.sh                    # start server on localhost:8080
#   bash tools/web-tester.sh --port 9000        # custom port
#   bash tools/web-tester.sh --docs             # generate HTML docs
#
# This is a testing utility only — NOT for production use.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

# Load environment
. "$REPO_ROOT/termux-backend/config/paths.sh"

PORT="${PORT:-8080}"
TEMP_DIR="${TEMP_DIR:-.}"
HTML_FILE="$TEMP_DIR/andrax-ui.html"
API_LOG="$TEMP_DIR/andrax-api.log"

# Parse arguments
for arg in "$@"; do
    case "$arg" in
        --port)
            shift
            PORT="$1"
            shift || true
            ;;
        --docs)
            shift
            GENERATE_DOCS_ONLY=true
            ;;
        *)
            ;;
    esac
done

# === Generate HTML UI ===

generate_html_ui() {
    cat > "$HTML_FILE" << 'EOF'
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>ANDRAX 2.0 — Web Tester</title>
    <style>
        * {
            margin: 0;
            padding: 0;
            box-sizing: border-box;
        }
        body {
            font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, "Helvetica Neue", Arial, sans-serif;
            background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
            min-height: 100vh;
            padding: 20px;
            color: #333;
        }
        .container {
            max-width: 1200px;
            margin: 0 auto;
            background: white;
            border-radius: 12px;
            box-shadow: 0 20px 60px rgba(0,0,0,0.3);
            overflow: hidden;
        }
        header {
            background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
            color: white;
            padding: 30px;
            text-align: center;
        }
        header h1 {
            font-size: 2.5em;
            margin-bottom: 10px;
        }
        header p {
            font-size: 1.1em;
            opacity: 0.9;
        }
        .content {
            display: grid;
            grid-template-columns: 1fr 1fr;
            gap: 30px;
            padding: 30px;
        }
        .panel {
            border: 1px solid #e0e0e0;
            border-radius: 8px;
            padding: 20px;
            background: #fafafa;
        }
        .panel h2 {
            color: #667eea;
            margin-bottom: 15px;
            font-size: 1.4em;
        }
        .tool-list {
            list-style: none;
            max-height: 400px;
            overflow-y: auto;
        }
        .tool-item {
            padding: 12px;
            margin: 8px 0;
            background: white;
            border-left: 4px solid #667eea;
            border-radius: 4px;
            cursor: pointer;
            transition: all 0.2s;
        }
        .tool-item:hover {
            background: #f0f4ff;
            border-left-color: #764ba2;
            transform: translateX(4px);
        }
        .tool-item.active {
            background: #e8eaf6;
            border-left-color: #764ba2;
        }
        .tool-name {
            font-weight: 600;
            color: #667eea;
            margin-bottom: 4px;
        }
        .tool-desc {
            font-size: 0.9em;
            color: #666;
            margin-bottom: 4px;
        }
        .tool-example {
            font-size: 0.85em;
            font-family: 'Courier New', monospace;
            background: white;
            padding: 4px 8px;
            border-radius: 3px;
            color: #764ba2;
        }
        .input-group {
            margin: 15px 0;
        }
        label {
            display: block;
            margin-bottom: 5px;
            font-weight: 600;
            color: #667eea;
        }
        input[type="text"],
        textarea,
        select {
            width: 100%;
            padding: 10px;
            border: 1px solid #ddd;
            border-radius: 4px;
            font-family: 'Courier New', monospace;
            font-size: 0.9em;
            transition: border-color 0.2s;
        }
        input[type="text"]:focus,
        textarea:focus,
        select:focus {
            outline: none;
            border-color: #667eea;
            box-shadow: 0 0 0 3px rgba(102, 126, 234, 0.1);
        }
        textarea {
            min-height: 100px;
            resize: vertical;
        }
        button {
            background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
            color: white;
            padding: 12px 24px;
            border: none;
            border-radius: 4px;
            font-size: 1em;
            font-weight: 600;
            cursor: pointer;
            transition: all 0.2s;
            width: 100%;
        }
        button:hover {
            transform: translateY(-2px);
            box-shadow: 0 10px 20px rgba(102, 126, 234, 0.2);
        }
        button:active {
            transform: translateY(0);
        }
        button:disabled {
            opacity: 0.6;
            cursor: not-allowed;
        }
        .output {
            background: #1e1e1e;
            color: #00ff00;
            padding: 15px;
            border-radius: 4px;
            font-family: 'Courier New', monospace;
            font-size: 0.85em;
            max-height: 300px;
            overflow-y: auto;
            white-space: pre-wrap;
            word-break: break-all;
            margin-top: 15px;
            line-height: 1.4;
        }
        .output.error {
            color: #ff6b6b;
        }
        .spinner {
            display: inline-block;
            width: 12px;
            height: 12px;
            border: 2px solid #f3f3f3;
            border-top: 2px solid #667eea;
            border-radius: 50%;
            animation: spin 1s linear infinite;
            margin-right: 8px;
        }
        @keyframes spin {
            0% { transform: rotate(0deg); }
            100% { transform: rotate(360deg); }
        }
        .status {
            padding: 10px;
            border-radius: 4px;
            margin-bottom: 15px;
            display: none;
        }
        .status.show {
            display: block;
        }
        .status.success {
            background: #d4edda;
            color: #155724;
            border: 1px solid #c3e6cb;
        }
        .status.error {
            background: #f8d7da;
            color: #721c24;
            border: 1px solid #f5c6cb;
        }
        .status.info {
            background: #d1ecf1;
            color: #0c5460;
            border: 1px solid #bee5eb;
        }
        .stats {
            display: grid;
            grid-template-columns: 1fr 1fr 1fr;
            gap: 10px;
            margin-top: 20px;
            padding-top: 20px;
            border-top: 1px solid #e0e0e0;
        }
        .stat-card {
            background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
            color: white;
            padding: 15px;
            border-radius: 8px;
            text-align: center;
        }
        .stat-value {
            font-size: 1.8em;
            font-weight: 700;
        }
        .stat-label {
            font-size: 0.9em;
            opacity: 0.9;
        }
        .tabs {
            display: flex;
            gap: 10px;
            margin-bottom: 15px;
            border-bottom: 2px solid #e0e0e0;
        }
        .tab-btn {
            background: none;
            border: none;
            padding: 10px 15px;
            color: #666;
            font-weight: 600;
            cursor: pointer;
            border-bottom: 2px solid transparent;
            margin-bottom: -2px;
            width: auto;
        }
        .tab-btn.active {
            color: #667eea;
            border-bottom-color: #667eea;
        }
        .tab-content {
            display: none;
        }
        .tab-content.active {
            display: block;
        }
        @media (max-width: 768px) {
            .content {
                grid-template-columns: 1fr;
            }
            header h1 {
                font-size: 1.8em;
            }
            .stats {
                grid-template-columns: 1fr;
            }
        }
    </style>
</head>
<body>
    <div class="container">
        <header>
            <h1>🎯 ANDRAX 2.0</h1>
            <p>Web Tester — Backend Testing UI</p>
        </header>

        <div class="content">
            <!-- Left panel: Tool/Workflow browser -->
            <div class="panel">
                <h2>📚 Tools & Workflows</h2>
                
                <div class="tabs">
                    <button class="tab-btn active" onclick="switchTab('tools')">Tools</button>
                    <button class="tab-btn" onclick="switchTab('workflows')">Workflows</button>
                </div>

                <div id="tools" class="tab-content active">
                    <ul id="toolList" class="tool-list"></ul>
                </div>

                <div id="workflows" class="tab-content">
                    <ul id="workflowList" class="tool-list"></ul>
                </div>

                <div class="stats">
                    <div class="stat-card">
                        <div class="stat-value" id="toolCount">0</div>
                        <div class="stat-label">Tools</div>
                    </div>
                    <div class="stat-card">
                        <div class="stat-value" id="categoryCount">0</div>
                        <div class="stat-label">Categories</div>
                    </div>
                    <div class="stat-card">
                        <div class="stat-value" id="workflowCount">0</div>
                        <div class="stat-label">Workflows</div>
                    </div>
                </div>
            </div>

            <!-- Right panel: Execution control -->
            <div class="panel">
                <h2>⚙️ Execute</h2>

                <div class="status" id="statusMessage"></div>

                <div class="input-group">
                    <label for="commandType">Type</label>
                    <select id="commandType" onchange="updateCommandDisplay()">
                        <option value="tool">Tool</option>
                        <option value="workflow">Workflow</option>
                    </select>
                </div>

                <div class="input-group">
                    <label for="selectedId">Selected ID</label>
                    <input type="text" id="selectedId" readonly placeholder="Click a tool or workflow">
                </div>

                <div class="input-group">
                    <label for="arguments">Arguments</label>
                    <textarea id="arguments" placeholder="Enter arguments (space-separated)"></textarea>
                </div>

                <button onclick="executeCommand()">
                    <span id="runButtonText">▶️ Run Command</span>
                </button>

                <div id="output" class="output" style="display: none;"></div>
            </div>
        </div>
    </div>

    <script>
        let registry = null;
        let selectedTool = null;
        let selectedWorkflow = null;

        // Load registry from server
        async function loadRegistry() {
            try {
                const response = await fetch('/api/registry');
                registry = await response.json();
                renderTools();
                renderWorkflows();
                updateStats();
            } catch (e) {
                showStatus('Failed to load registry: ' + e.message, 'error');
            }
        }

        // Render tools list
        function renderTools() {
            if (!registry) return;
            const list = document.getElementById('toolList');
            list.innerHTML = '';
            
            registry.categories.forEach(cat => {
                cat.tools.forEach(tool => {
                    const item = document.createElement('li');
                    item.className = 'tool-item';
                    item.innerHTML = `
                        <div class="tool-name">${tool.name}</div>
                        <div class="tool-desc">${tool.description}</div>
                        <div class="tool-example">${tool.example}</div>
                    `;
                    item.onclick = () => selectTool(tool.id, item);
                    list.appendChild(item);
                });
            });
        }

        // Render workflows list
        function renderWorkflows() {
            if (!registry) return;
            const list = document.getElementById('workflowList');
            list.innerHTML = '';
            
            registry.workflows.forEach(wf => {
                const item = document.createElement('li');
                item.className = 'tool-item';
                item.innerHTML = `
                    <div class="tool-name">${wf.name}</div>
                    <div class="tool-desc">${wf.description}</div>
                    <div class="tool-example">${wf.example}</div>
                `;
                item.onclick = () => selectWorkflow(wf.id, item);
                list.appendChild(item);
            });
        }

        // Select tool
        function selectTool(toolId, element) {
            document.querySelectorAll('#toolList .tool-item').forEach(e => e.classList.remove('active'));
            element.classList.add('active');
            selectedTool = toolId;
            selectedWorkflow = null;
            document.getElementById('commandType').value = 'tool';
            document.getElementById('selectedId').value = toolId;
            updateCommandDisplay();
        }

        // Select workflow
        function selectWorkflow(wfId, element) {
            document.querySelectorAll('#workflowList .tool-item').forEach(e => e.classList.remove('active'));
            element.classList.add('active');
            selectedWorkflow = wfId;
            selectedTool = null;
            document.getElementById('commandType').value = 'workflow';
            document.getElementById('selectedId').value = wfId;
            updateCommandDisplay();
        }

        // Update stats
        function updateStats() {
            if (!registry) return;
            let toolCount = 0;
            registry.categories.forEach(cat => toolCount += cat.tools.length);
            document.getElementById('toolCount').textContent = toolCount;
            document.getElementById('categoryCount').textContent = registry.categories.length;
            document.getElementById('workflowCount').textContent = registry.workflows.length;
        }

        // Switch tabs
        function switchTab(tab) {
            document.querySelectorAll('.tab-content').forEach(el => el.classList.remove('active'));
            document.querySelectorAll('.tab-btn').forEach(el => el.classList.remove('active'));
            document.getElementById(tab).classList.add('active');
            event.target.classList.add('active');
        }

        // Execute command
        async function executeCommand() {
            const id = document.getElementById('selectedId').value;
            const args = document.getElementById('arguments').value.trim();
            const type = document.getElementById('commandType').value;

            if (!id) {
                showStatus('Please select a ' + type, 'error');
                return;
            }

            const endpoint = type === 'tool' ? '/api/run-tool' : '/api/run-workflow';
            const payload = { id, args };

            document.getElementById('runButtonText').innerHTML = '<span class="spinner"></span>Running...';
            const runBtn = event.target;
            runBtn.disabled = true;

            try {
                const response = await fetch(endpoint, {
                    method: 'POST',
                    headers: { 'Content-Type': 'application/json' },
                    body: JSON.stringify(payload)
                });
                
                const result = await response.json();
                
                if (result.success) {
                    showOutput(result.output);
                    showStatus('✅ Command executed successfully', 'success');
                } else {
                    showOutput(result.error || 'Unknown error');
                    showStatus('❌ Command failed', 'error');
                }
            } catch (e) {
                showOutput('Request failed: ' + e.message);
                showStatus('❌ Request failed: ' + e.message, 'error');
            } finally {
                document.getElementById('runButtonText').textContent = '▶️ Run Command';
                runBtn.disabled = false;
            }
        }

        // Show output
        function showOutput(text) {
            const output = document.getElementById('output');
            output.textContent = text;
            output.style.display = 'block';
        }

        // Show status message
        function showStatus(message, type) {
            const status = document.getElementById('statusMessage');
            status.textContent = message;
            status.className = 'status show ' + type;
            setTimeout(() => status.classList.remove('show'), 5000);
        }

        // Update command display
        function updateCommandDisplay() {
            // Logic for updating what's shown
        }

        // Load on startup
        loadRegistry();
    </script>
</body>
</html>
EOF
    echo "✅ Generated HTML UI: $HTML_FILE"
}

# === Simple HTTP Server (using Python or nc) ===

start_server() {
    echo ""
    echo "════════════════════════════════════════════════════════"
    echo "🚀 ANDRAX 2.0 Web Tester"
    echo "════════════════════════════════════════════════════════"
    echo ""
    echo "📍 Server: http://localhost:$PORT"
    echo "📂 HTML:   $HTML_FILE"
    echo "📝 Logs:   $API_LOG"
    echo ""
    echo "Press Ctrl+C to stop"
    echo "════════════════════════════════════════════════════════"
    echo ""

    # Start simple Python HTTP server with CGI support
    if command -v python3 >/dev/null 2>&1; then
        cd "$TEMP_DIR"
        python3 << PYEOF
import http.server
import socketserver
import json
import subprocess
import os

PORT = $PORT
REGISTRY_PATH = "$ANDRAX_REGISTRY"
HTML_FILE = "$HTML_FILE"

class APIHandler(http.server.SimpleHTTPRequestHandler):
    def do_GET(self):
        if self.path == '/':
            self.send_response(200)
            self.send_header('Content-type', 'text/html')
            self.end_headers()
            with open(HTML_FILE, 'rb') as f:
                self.wfile.write(f.read())
        elif self.path == '/api/registry':
            try:
                with open(REGISTRY_PATH, 'r') as f:
                    data = json.load(f)
                self.send_response(200)
                self.send_header('Content-type', 'application/json')
                self.end_headers()
                self.wfile.write(json.dumps(data).encode())
            except Exception as e:
                self.send_response(500)
                self.send_header('Content-type', 'application/json')
                self.end_headers()
                self.wfile.write(json.dumps({'error': str(e)}).encode())
        else:
            self.send_response(404)
            self.end_headers()

    def do_POST(self):
        content_length = int(self.headers.get('Content-Length', 0))
        body = self.rfile.read(content_length).decode()
        
        try:
            data = json.loads(body)
            cmd_id = data.get('id', '')
            args = data.get('args', '')
            
            if self.path == '/api/run-tool':
                result = self._run_tool(cmd_id, args)
            elif self.path == '/api/run-workflow':
                result = self._run_workflow(cmd_id, args)
            else:
                result = {'success': False, 'error': 'Unknown endpoint'}
            
            self.send_response(200)
            self.send_header('Content-type', 'application/json')
            self.end_headers()
            self.wfile.write(json.dumps(result).encode())
        except Exception as e:
            self.send_response(500)
            self.send_header('Content-type', 'application/json')
            self.end_headers()
            self.wfile.write(json.dumps({'success': False, 'error': str(e)}).encode())

    def _run_tool(self, tool_id, args):
        try:
            cmd = ['bash', '-c', f'source $ANDRAX_BACKEND/config/env.sh && andrax run-tool {tool_id} -- {args}']
            result = subprocess.run(cmd, capture_output=True, text=True, timeout=30)
            return {
                'success': result.returncode == 0,
                'output': result.stdout + result.stderr
            }
        except subprocess.TimeoutExpired:
            return {'success': False, 'output': 'Command timed out (30s)'}
        except Exception as e:
            return {'success': False, 'error': str(e)}

    def _run_workflow(self, wf_id, args):
        try:
            cmd = ['bash', '-c', f'source $ANDRAX_BACKEND/config/env.sh && andrax run-workflow {wf_id} -- {args}']
            result = subprocess.run(cmd, capture_output=True, text=True, timeout=60)
            return {
                'success': result.returncode == 0,
                'output': result.stdout + result.stderr
            }
        except subprocess.TimeoutExpired:
            return {'success': False, 'output': 'Command timed out (60s)'}
        except Exception as e:
            return {'success': False, 'error': str(e)}

    def log_message(self, format, *args):
        with open("$API_LOG", "a") as f:
            f.write(self.client_address[0] + " - " + format%args + "\n")

if __name__ == '__main__':
    with socketserver.TCPServer(("", PORT), APIHandler) as httpd:
        print(f"Server running on http://localhost:{PORT}")
        httpd.serve_forever()
PYEOF
    else
        echo "❌ Python 3 not found. Install it to run the web server."
        exit 1
    fi
}

# === Main ===

if [ "${GENERATE_DOCS_ONLY:-false}" = "true" ]; then
    generate_html_ui
else
    generate_html_ui
    start_server
fi
