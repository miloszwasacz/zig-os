pub fn exit_qemu() callconv(.c) noreturn {
    // APM shutdown procedure
    asm volatile (
        \\ # Perform an installation check
        \\ movb $0x53, %ah
        \\ movb $0x00, %al
        \\ xorw %bx, %bx
        \\ int $0x15
        \\ jc APM_error
        \\
        \\ # Connect to an APM interface
        \\ movb $0x53, %ah
        \\ movb $0x01, %al
        \\ xorw %bx, %bx
        \\ int $0x15
        \\ jc APM_error
        \\
        \\ # Set APM Driver Version
        \\ movb $0x53, %ah
        \\ movb $0x0e, %al
        \\ movw $0x0000, %bx
        \\ movb $0x01, %ch
        \\ movb $0x01, %cl
        \\ int $0x15
        \\ jc .version_error
        \\ jmp .no_error
        \\ .version_error:
        \\ jmp APM_error
        \\ .no_error:
        \\
        \\ # Enable power management for all devices
        \\ movb $0x53, %ah
        \\ movb $0x08, %al
        \\ movw $0x0001, %bx
        \\ movw $0x0001, %cx
        \\ int $0x15
        \\ jc APM_error
        \\
        \\ # Set the power state for all devices
        \\ movb $0x53, %ah
        \\ movb $0x07, %al
        \\ movw $0x0001, %bx
        \\ movw $0x0001, %cx
        \\ int $0x15
        \\ jc APM_error
        \\
        \\ APM_error:
        ::: .{ .ah = true, .al = true, .bx = true, .ch = true, .cl = true });

    while (true) {}
}
