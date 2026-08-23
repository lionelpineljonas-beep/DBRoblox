import http.server
import json

class LogHandler(http.server.SimpleHTTPRequestHandler):
    def do_POST(self):
        content_length = int(self.headers['Content-Length'])
        post_data = self.rfile.read(content_length)
        
        try:
            data = json.loads(post_data.decode('utf-8'))
            message = data.get('message', '')
            msg_type = data.get('type', 'INFO')
            
            with open('roblox_output.log', 'a', encoding='utf-8') as f:
                f.write(f"[{msg_type}] {message}\n")
                
            self.send_response(200)
            self.end_headers()
            self.wfile.write(b"OK")
        except Exception as e:
            self.send_response(400)
            self.end_headers()
            self.wfile.write(str(e).encode('utf-8'))
            
    def log_message(self, format, *args):
        pass # Suppress standard HTTP server logging

if __name__ == '__main__':
    server = http.server.HTTPServer(('localhost', 8080), LogHandler)
    with open('roblox_output.log', 'w', encoding='utf-8') as f:
        f.write("--- ROBLOX LOGGING STARTED ---\n")
    print("Listening for Roblox logs on localhost:8080...")
    server.serve_forever()
