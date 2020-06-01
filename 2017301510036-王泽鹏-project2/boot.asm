assume cs:code
data segment
	; db 512 dup (0)
	db 510 dup (0)
	dw 0aa55h
data ends
code segment
	start:
		call setup
		call write	; 调用写磁盘函数

		mov ax,4c00h
		int 21h
	; 安装程序，将下面的引导程序boot安装到内存data处，后面调用write函数将内存内容写入磁盘
	setup:
		mov ax,cs
		mov ds,ax
		mov si,offset boot
		
		mov ax,data
		mov es,ax
		mov di,0
		mov cx,offset bootend - offset boot
		cld
		rep movsb
		ret
	; 将上面的boot模块从内存写入磁盘0面0道1扇区
	write:
		mov ax,data
		mov es,ax
		mov bx,0	; es:bx为要写入磁盘数据在内存中的地址
		
		mov al,1
		mov ch,0
		mov cl,1
		mov dl,0
		mov dh,0
		
		mov ah,3
		int 13h
		ret
		
	; -------------------以下为引导程序代码部分-----------------------------------------------
	; 引导程序boot作用：
	; 1.读扇区，将0面0道2扇区的任务程序task写到内存0000:7E00H处
	; 2.将CS:IP改为0000:7E00H
	boot:
		jmp short bootstart
		db 10 dup(0)
	bootstart:
		mov ax,cs
		mov ss,ax
		mov sp,10
		
		mov ax,0
		mov es,ax
		mov bx,7E00H	; es:bx为目标内存区地址
		
		mov al,3	; 读取的扇区数，程序较大，task占3扇区的空间
		mov ch,0	; 磁道号
		mov cl,2	; 扇区号
		mov dl,0	; 驱动器号
		mov dh,0	; 磁头号（对于软盘即面号）
		
		mov ah,2	; 功能号，2为读扇区
		int 13h
		
		mov bx,0
		push bx
		mov bx,7E00H
		push bx
		retf	; 利用retf指令实现远转移，相当于pop IP、CS
	bootend:
		nop

	code ends
	end start
	
	
	
	