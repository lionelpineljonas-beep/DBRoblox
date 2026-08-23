import sys
import json
import subprocess
import threading
import os

def read_message(stream):
    header = b""
    while True:
        line = stream.readline()
        if not line:
            return None
        if line == b"\r\n":
            break
        header += line
    
    header_str = header.decode('ascii')
    content_length = 0
    for line in header_str.split('\r\n'):
        if line.lower().startswith("content-length:"):
            content_length = int(line.split(":")[1].strip())
            break
            
    if content_length == 0:
        return None
        
    body = stream.read(content_length)
    return body

def write_message(stream, msg_dict):
    body = json.dumps(msg_dict).encode('utf-8')
    header = f"Content-Length: {len(body)}\r\n\r\n".encode('ascii')
    stream.write(header)
    stream.write(body)
    stream.flush()

def forward_stdout(proc):
    while True:
        msg = read_message(proc.stdout)
        if not msg:
            break
        body = json.loads(msg.decode('utf-8'))
        write_message(sys.stdout.buffer, body)

def main():
    localappdata = os.environ.get('LOCALAPPDATA', '')
    cmd = ["cmd.exe", "/c", f"cd /d {localappdata}\\Roblox && .\\mcp.bat"]
    
    # Start real StudioMCP
    proc = subprocess.Popen(cmd, stdin=subprocess.PIPE, stdout=subprocess.PIPE, stderr=sys.stderr)
    
    # Thread to forward stdout
    t = threading.Thread(target=forward_stdout, args=(proc,))
    t.daemon = True
    t.start()
    
    # Forward stdin, but intercept server/discover
    while True:
        msg = read_message(sys.stdin.buffer)
        if not msg:
            break
            
        body = json.loads(msg.decode('utf-8'))
        
        if body.get("method") == "server/discover":
            response = {
                "jsonrpc": "2.0",
                "id": body.get("id"),
                "result": {}
            }
            write_message(sys.stdout.buffer, response)
            continue
            
        write_message(proc.stdin, body)
        
if __name__ == "__main__":
    main()
