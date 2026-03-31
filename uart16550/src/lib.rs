#![no_std]

use core::mem::MaybeUninit;
use core::panic::PanicInfo;
use uart_16550::{backend::PioBackend, Config, Uart16550};

unsafe extern "C" { fn handle_rust_panic() -> !; }

const PORT_ADDR: u16 = 0x3f8;

#[repr(transparent)]
pub struct SerialPort(Uart16550<PioBackend>);

static mut UART: MaybeUninit<SerialPort> = MaybeUninit::uninit();
    
#[unsafe(no_mangle)]
#[allow(static_mut_refs)]
pub extern "C" fn init_serial() -> *mut SerialPort {
    let mut serial_port = unsafe { Uart16550::new_port(PORT_ADDR).unwrap() };
    serial_port.init(Config::default()).expect("should init device successfully");
    unsafe {
        UART.write(SerialPort(serial_port));
        UART.as_mut_ptr()
    }
}

#[unsafe(no_mangle)]
pub extern "C" fn send_bytes_to_serial(uart: *mut SerialPort, len: usize, buf: *const u8) {
    let uart = unsafe { &mut (*uart) };
    let slice = unsafe { core::slice::from_raw_parts(buf, len) };
    uart.0.send_bytes_exact(slice);
}

#[panic_handler]
fn panic(_info: &PanicInfo) -> ! {
    unsafe { handle_rust_panic() }
}
