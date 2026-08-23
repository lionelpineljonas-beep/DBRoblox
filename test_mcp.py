import sys
import json
import subprocess
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
        
    return stream.read(content_length)

def write_message(stream, msg_dict):
    body = json.dumps(msg_dict).encode('utf-8')
    header = f"Content-Length: {len(body)}\r\n\r\n".encode('ascii')
    stream.write(header)
    stream.write(body)
    stream.flush()

def main():
    localappdata = os.environ.get('LOCALAPPDATA', '')
    cmd = ["cmd.exe", "/c", f"cd /d {localappdata}\\Roblox && .\\mcp.bat"]
    proc = subprocess.Popen(cmd, stdin=subprocess.PIPE, stdout=subprocess.PIPE, stderr=sys.stderr)
    
    # Send initialize
    init_req = {
        "jsonrpc": "2.0",
        "id": 1,
        "method": "initialize",
        "params": {
            "protocolVersion": "2024-11-05",
            "capabilities": {},
            "clientInfo": {"name": "test", "version": "1.0"}
        }
    }
    write_message(proc.stdin, init_req)
    resp = read_message(proc.stdout)
    print("Init response:", resp)
    
    write_message(proc.stdin, {"jsonrpc": "2.0", "method": "notifications/initialized"})
    
    # Send tools/list
    tools_req = {
        "jsonrpc": "2.0",
        "id": 2,
        "method": "tools/list",
        "params": {}
    }
    write_message(proc.stdin, tools_req)
    resp2 = read_message(proc.stdout)
    print("Tools list:", resp2)

if __name__ == "__main__":
    main()
