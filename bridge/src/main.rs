//! One request per process/connection. Hardware is controlled exclusively by Unified IPC.
use serde_json::{json, Value};
use std::{
    env, fs,
    io::{BufRead, BufReader, Write},
    os::{
        fd::AsRawFd,
        unix::{fs::MetadataExt, net::UnixStream},
    },
    time::{Duration, SystemTime, UNIX_EPOCH},
};

fn exchange(method: &str, params: Value) -> Result<Value, Box<dyn std::error::Error>> {
    if !params.is_object() {
        return Err("Parameters must be a JSON object".into());
    }
    let runtime = env::var("XDG_RUNTIME_DIR")?;
    let meta = fs::symlink_metadata(&runtime)?;
    let uid = unsafe { libc::geteuid() };
    if !meta.is_dir() || meta.uid() != uid || meta.mode() & 0o077 != 0 {
        return Err("Unsafe runtime directory ownership or permissions".into());
    }
    let id = format!(
        "{}-{}",
        std::process::id(),
        SystemTime::now().duration_since(UNIX_EPOCH)?.as_nanos()
    );
    let mut frame =
        serde_json::to_vec(&json!({"version":1,"id":id,"method":method,"params":params}))?;
    frame.push(b'\n');
    if frame.len() > 8192 {
        return Err("Request exceeds 8192 bytes".into());
    }
    let mut stream = UnixStream::connect(std::path::Path::new(&runtime).join("ghelper.sock"))?;
    let mut peer: libc::ucred = unsafe { std::mem::zeroed() };
    let mut len = std::mem::size_of::<libc::ucred>() as libc::socklen_t;
    if unsafe {
        libc::getsockopt(
            stream.as_raw_fd(),
            libc::SOL_SOCKET,
            libc::SO_PEERCRED,
            &mut peer as *mut _ as *mut _,
            &mut len,
        )
    } != 0
    {
        return Err(std::io::Error::last_os_error().into());
    }
    if peer.uid != uid {
        return Err("Unexpected IPC peer".into());
    }
    // A disconnected wait cannot undo a hardware operation. Never retry mutations.
    stream.set_read_timeout(Some(Duration::from_secs(300)))?;
    stream.set_write_timeout(Some(Duration::from_secs(10)))?;
    stream.write_all(&frame)?;
    let mut reader = BufReader::new(stream);
    let mut response = Vec::new();
    loop {
        let available = reader.fill_buf()?;
        if available.is_empty() {
            return Err("Incomplete IPC response".into());
        }
        let n = available
            .iter()
            .position(|&b| b == b'\n')
            .map_or(available.len(), |n| n + 1);
        if response.len() + n > 1024 * 1024 {
            return Err("Oversized IPC response".into());
        }
        response.extend_from_slice(&available[..n]);
        reader.consume(n);
        if response.last() == Some(&b'\n') {
            break;
        }
    }
    let value: Value = serde_json::from_slice(&response)?;
    if value["version"] != 1 || value["id"] != id || !value["ok"].is_boolean() {
        return Err("IPC response mismatch".into());
    }
    Ok(value)
}
fn main() {
    let args: Vec<String> = env::args().collect();
    let result = (|| {
        let method = args
            .get(1)
            .ok_or("Usage: rog-ipc-bridge METHOD [JSON_PARAMS]")?;
        let params = serde_json::from_str(args.get(2).map(String::as_str).unwrap_or("{}"))?;
        exchange(method, params)
    })();
    match result {
        Ok(value) => println!("{value}"),
        Err(err) => {
            println!(
                "{}",
                json!({"version":1,"ok":false,"error":{"code":"transport_error","message":err.to_string()}})
            );
            std::process::exit(1);
        }
    }
}
