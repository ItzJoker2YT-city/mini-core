#![no_std]
#![no_main]
use core::{arch::asm, panic::PanicInfo};
unsafe fn syscall3(n: usize, a: usize, b: usize, c: usize) -> isize {
    let r: isize;
    asm!("syscall", inlateout("rax") n => r, in("rdi") a, in("rsi") b, in("rdx") c, lateout("rcx") _, lateout("r11") _, options(nostack));
    r
}
fn write(s: &[u8]) { unsafe { syscall3(1, 1, s.as_ptr() as usize, s.len()); } }
fn run(args: &[*const u8]) {
    unsafe {
        let pid = syscall3(57, 0, 0, 0);
        if pid == 0 {
            let env = [b"PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin\0".as_ptr(), b"HOME=/root\0".as_ptr(), b"TERM=vt100\0".as_ptr(), core::ptr::null()];
            syscall3(59, args[0] as usize, args.as_ptr() as usize, env.as_ptr() as usize);
            syscall3(60, 127, 0, 0);
        } else if pid > 0 {
            // wait4 has a fourth argument; set it explicitly to a null rusage pointer.
            loop {
                let r: isize;
                asm!("syscall", inlateout("rax") 61usize => r, in("rdi") usize::MAX, in("rsi") 0usize, in("rdx") 0usize, in("r10") 0usize, lateout("rcx") _, lateout("r11") _, options(nostack));
                if r == pid || r == -10 { break; }
            }
        } else { write(b"tiny-rust: fork failed\n"); }
    }
}
#[no_mangle]
pub extern "C" fn _start() -> ! {
    write(b"mini-core: Rust PID 1 started\n");
    run(&[b"/bin/sh\0".as_ptr(), b"/etc/rc\0".as_ptr(), core::ptr::null()]);
    loop {
        run(&[b"/bin/setsid\0".as_ptr(), b"cttyhack\0".as_ptr(), b"/usr/local/sbin/tiny-console\0".as_ptr(), core::ptr::null()]);
        // Avoid a busy respawn loop if the console is unavailable.
        run(&[b"/bin/sleep\0".as_ptr(), b"1\0".as_ptr(), core::ptr::null()]);
    }
}
#[panic_handler]
fn panic(_: &PanicInfo) -> ! { loop { unsafe { syscall3(34, 0, 0, 0); } } }
