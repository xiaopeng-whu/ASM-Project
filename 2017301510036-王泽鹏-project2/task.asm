assume cs:code
data segment
	db 1536 dup (0)	; task程序越来越大，之前512字节不够存，直接分配3扇区的内存（坑了我好久...）
data ends
code segment
	start:
		call setup
		call write	; 调用写磁盘函数
		
		mov ax,4c00h
		int 21h
	; 安装程序，将下面的任务程序task安装到内存data处，后面调用write函数将内存内容写入磁盘
	setup:
		mov ax,cs
		mov ds,ax
		mov si,offset task
		
		mov ax,data
		mov es,ax
		mov di,0
		mov cx,offset taskend - offset task
		cld
		rep movsb
		ret
	; 将task模块从内存写入磁盘0面0道2扇区
	write:
		mov ax,data
		mov es,ax
		mov bx,0	; es:bx为要写入磁盘数据在内存中的地址
		
		mov al,3
		mov ch,0
		mov cl,2
		mov dl,0
		mov dh,0
		
		mov ah,3
		int 13h
		ret
		
	; ------------------------------------------------------------------	
	;        以下为任务程序代码部分
	;         task------task end
	; ------------------------------------------------------------------	
	task:
		jmp taskstart
		function_1 db '1) reset pc',0
		function_2 db '2) start system',0
		function_3 db '3) clock',0
		function_4 db '4) set clock',0
		; 字符串地址表，便于后续循环的使用
		function_address	dw offset function_1 - offset task + 7E00H
							dw offset function_2 - offset task + 7E00H
							dw offset function_3 - offset task + 7E00H
							dw offset function_4 - offset task + 7E00H
		time db '00/00/00 00:00:00',0
		time_address db 9,8,7,4,2,0	; 端口时间地址列表
		number_stack db 12 dup ('*') ,0	; 保存修改时间时的12个数字
		; 以下为提示信息字符串
		tip_0	db 'Copr. 2020 WangZePeng,WHU.All Rights Reserved.',0
		tip_1	db 'Please choose a number(1~4).',0
		tip_2	db 'Press [F1] to change the color and [ESC] to quit.',0
		tip_3	db 'Please input the date and time. Make sure that your input is legal.',0
		
		
	taskstart:
		mov ax,0b800h
		mov es,ax
		mov ax,0
		mov ds,ax

		call clear_screen
		call function_list
		jmp choose_option
		
		mov ax,4c00h
		int 21h
		
	; ------------------------------------------------------------------
	;  clear_screen:         
	;			清屏函数，用空格替换当前屏幕（参考课设1的思路）
	; ------------------------------------------------------------------	
	clear_screen:
		push dx
		push bx
		push cx
		
		; mov dl,0
		; mov dh,0
		mov dx,1F00H	; 黑屏白字
		mov bx,0
		; mov cx,4000	
		mov cx,2000	; 一页4000个字节循环2000次应该就可以了
	s:
		mov es:[bx],dx
		add bx,2
		loop s
		
		pop cx
		pop bx
		pop dx
	ret
	
	; ------------------------------------------------------------------
	;  choose_option:         
	;			读取键盘输入选择1-4号功能
	;  int 16h中断的0号功能，读取一个键盘输入
	;  ah为扫描码，al为ASCII码
	; ------------------------------------------------------------------
	choose_option:
		mov ah,0	; 设置功能号
		int 16h
	; key_input:
		cmp ah,02h	; 1的扫描码
		je option_1
		cmp ah,03h
		je option_2
		cmp ah,04h
		je option_3
		cmp ah,05h
		je option_4
		; jmp short key_input	; 不能在这里jmp...
		jmp choose_option	; 如果不是1234，忽略重新等待输入
	; 如果输入1234以外的字符再按1，无效，缓冲区？此处存疑...
	; 已解决，上面的jmp错导致无限循环
	option_1:
		call reset_pc
		; jmp short taskstart	; 重启计算机会自动跳到主界面
	option_2:
		; call start_system
		jmp start_system	; 用call就会出错，很奇怪，此处存疑...
		; jmp short taskstart	; 启动计算机后不用跳到主界面
	option_3:
		call clock
		jmp taskstart
	option_4:
		call set_clock
		jmp taskstart
	
	
	; ------------------------------------------------------------------
	;  reset_pc:         
	;			重启计算机（ffff:0单元）
	; ------------------------------------------------------------------
	reset_pc:
		; jmp ffff:0
		mov ax,0ffffh
		push ax
		mov ax,0
		push ax
		retf	;pop IP、pop CS
	ret	; call调用一定记得要ret...
	
	; ------------------------------------------------------------------
	;  start_system:         
	;			引导现有的操作系统
	;       读取硬盘C盘0面0道1扇区的内容到0000:7C00H
	;       将CS:IP指向0000:7C00H
	; （在执行其他三个功能后，有时会出现问题：
	;      执行了清屏函数说明可以进入，但没有继续启动..存疑）
	; ------------------------------------------------------------------
	start_system:
		call clear_screen
		
		mov ax,0
		mov es,ax
		mov bx,7C00H
		
		mov al,1
		mov ch,0
		mov cl,1
		mov dl,80h	; 硬盘C：80h
		mov dh,0
		
		mov ah,2
		int 13h
		
		; jmp 0000:7C00H
		mov ax,0
		push ax
		mov ax,7C00H
		push ax
		retf
	; ret
		
	; ------------------------------------------------------------------
	;  clock:         
	;			动态显示当前时间（循环读取CMOS、键盘中断）
	;		   按下F1改变颜色，按下Esc返回到主界面
	; ------------------------------------------------------------------
	clock:
		mov ax,0b800h
		mov es,ax
		mov ax,0
		mov ds,ax
		call clear_screen
		; jmp change_color	; 先让属性字节从1开始，否则下面显示时间为黑色
		; call get_time
		; mov si,offset time - offset task + 7E00H
		; mov di,160*12+30*2
		; call print_time
		
		; 提示信息显示
		mov si,offset tip_2 - offset task + 7E00H
		mov di,160*15+15*2
		call print_time
		
		clock_loop:
			call get_time
			mov si,offset time - offset task + 7E00H
			mov di,160*12+30*2
			call print_time
			
			; 读取键盘缓冲区
			mov ah,1	; 非阻塞式读取，使用0会阻塞后面的运行
			int 16h
			; jz clock_loop	; ZF=1表示无按键按下，跳转
			cmp ah,3bh	; F1的扫描码
			je change_color
			cmp al,1bh	; ESC的扫描码为1，与功能号冲突，故用ASCII码
			je clock_quit
			; 上面两个扫描码都留在了缓冲区，需要清空
			cmp al,0	; 其他键盘中断
			jne clear_key_buffer_caller	; 清除其他键盘中断
			
		; clock_loop_end:
			jmp clock_loop
	; ------------------------------------------------------------------
	;  clock_quit:         
	;			ESC退出时钟显示程序
	; ------------------------------------------------------------------
	clock_quit:
		call clear_key_buffer
		jmp taskstart	; 退出时钟程序返回主界面
	; ------------------------------------------------------------------
	;  clear_key_buffer:         
	;			清空键盘缓冲区
	; ------------------------------------------------------------------
	clear_key_buffer_caller:
		call clear_key_buffer
		jmp clock_loop
	clear_key_buffer:
		mov ah,1
		int 16h
		jz clear_key_buffer_end	; 非阻塞读取数据为0，清空结束

		mov ah,0	; 采用阻塞式读取清空一次缓冲区
		int 16h
		jmp clear_key_buffer
	clear_key_buffer_end:
		ret
	; ------------------------------------------------------------------
	;  get_time:         
	;			获取当前时间（参考实验14）
	;			有时候开机滴的一声然后时间不正确，存疑..
	; ------------------------------------------------------------------
	get_time:
		mov si,offset time - offset task + 7E00H
		; mov di,160*12+30*2
		mov cx,6	; 循环6次得到年月日时分秒
		mov bx,offset time_address - offset task + 7E00H ; 端口时间地址列表首地址
		; call print_time
		
		store_time: ; 将CMOS取出的日期时间存到data区
			push cx
			mov ax,[bx]
			out 70h,al
			in al,71h
			
			mov ah,al
			mov cl,4
			shr ah,cl
			and al,00001111b
			
			add ah,30h
			add al,30h
			
			mov [si],ah
			mov [si+1],al
			
			inc bx
			add si,3
			pop cx
			loop store_time
		; jmp get_time
	ret
	; ------------------------------------------------------------------
	;  print_time:         
	;			将存入data区的时间格式打印到显存
	; ------------------------------------------------------------------
	print_time:	
		push si
		push ax
		push di
	print_time_start:
		mov al,[si]
		cmp al,0	; 通过结尾符0来判断是否继续打印
		je print_time_end
		; mov ah,1	; 我吐了一开始把属性值设为0了，看不到结果，找了半天错
		; 把属性设置去掉，因为会改变颜色，这里就不能设置了
		; 但这样会导致初始为黑色，还是什么都看不到，考虑调用一次change_color?
		mov es:[di],al
		; mov es:[di+1],ah
		add di,2
		inc si
		jmp print_time_start
	print_time_end:
		pop di
		pop ax
		pop si
		ret
	; ------------------------------------------------------------------
	;  change_color:         
	;			改变颜色函数，通过循环增加属性字段实现
	; ------------------------------------------------------------------
	change_color:
		push bx
		push cx
		
		mov bx,1	; 从第一个高位属性字节开始
		mov cx,2000	; 2000个字符，2000个属性字节
	colors:
		inc byte ptr es:[bx]	; 属性字节加1，实现颜色的改变
		or	byte ptr es:[bx],00001000b	; 高亮设置
		and byte ptr es:[bx],10001111b	; 背景设置为黑色
		; 切换多次会出现闪烁，此处存疑...
		add bx,2
		loop colors
		
		pop cx
		pop bx
		
		call clear_key_buffer
		jmp clock_loop	; 改变颜色后返回时钟循环
	
	; ------------------------------------------------------------------
	;  set_clock:         
	;			更改日期、时间，更改后返回主界面（输入字符串）
	;      注意时间不能越界（如月份小于13），这里用提示信息来作提醒
	;   待优化：输入格式界面更加友好，如每两个数字后面加一个空格
	;			但由于是采用修改数字栈再打印的方法实现显示，有些不好操作
	; ------------------------------------------------------------------
	set_clock:
		mov ax,0b800h
		mov es,ax
		mov ax,0
		mov ds,ax
		call clear_screen
		call clear_number_stack
		
		; 提示信息显示
		mov si,offset tip_3 - offset task + 7E00H
		mov di,160*15+5*2
		call print_time
		
		; 显示数字栈初始值（全*）
		mov di,160*12+30*2
		mov si,offset number_stack - offset task + 7E00H
		call print_time
		
		call get_input_time
		call set_cmos
		
	ret
	
	; ------------------------------------------------------------------
	;  get_input_time:         
	;			输入日期时间信息的函数，主要是对字符栈的操作
	; ------------------------------------------------------------------
	get_input_time:
		mov si,offset number_stack - offset task + 7E00H
		mov bx,0	; 作为输入字符计数器
	get_input_loop:
		mov ah,0
		int 16h
		cmp al,'0'	; 比较ASCII码判断是否为数字
		jb not_number
		cmp al,'9'
		ja not_number
		call push_number	; 如果是数字则入栈	
		; cmp bx,12	; 在这里判断会导致第13个字符入栈
		; ja stack_full	; 超过12个字符结束输入
		mov di,160*12+30*2
		; push si
		call print_time ; 这个函数会导致si改变...吐了
		; pop si
		jmp get_input_loop
	not_number:
		cmp ah,0EH	; 退格键
		je backspacekey
		cmp ah,1CH	; 回车键
		je enterkey
		jmp get_input_loop
		
	backspacekey:
		call pop_number
		mov di,160*12+30*2
		call print_time
		jmp get_input_loop
	enterkey:
		ret
		
	; stack_full:
		; ret
	
	push_number:
		cmp bx,12	; 当bx到12时，实际上这是第13个位置，即此时栈已满
		jz push_number_end
		mov [si+bx],al
		inc bx
	push_number_end:
		ret
		
	pop_number:
		cmp bx,0
		je pop_number_end
		dec bx	; 应该先自减，因为此时指针指向要清除值的后一个位置
		mov byte ptr [si+bx],'*'
	pop_number_end:
		ret
		
	; ------------------------------------------------------------------
	;  set_cmos:         
	;			更改CMOS RAM中存储的时间信息
	;           就是get_time的逆过程
	; ------------------------------------------------------------------
	set_cmos:
		mov bx,offset time_address - offset task + 7E00H
		mov si,offset number_stack - offset task + 7E00H
		mov cx,6
		
		change_cmos:
			push cx
			mov dx,[si]
			sub dx,3030H
			mov cl,4
			shl dl,cl
			and dh,00001111b
			or dl,dh
			
			mov al,[bx]
			out 70h,al
			mov al,dl
			out 71h,al
			
			inc bx
			add si,2
			pop cx
			loop change_cmos
		ret
	
	; ------------------------------------------------------------------
	;  clear_number_stack:         
	;			清空数字栈，设为初始值******
	; ------------------------------------------------------------------
	clear_number_stack:
		push bx
		push cx
		
		mov bx,offset number_stack - offset task + 7E00H
		mov cx,6
		s1:
			mov word ptr ds:[bx],'**'
			add bx,2
		loop s1
		
		pop cx
		pop bx
	ret
	
	
	; ------------------------------------------------------------------
	;  function_list:         
	;			主界面
	;           显示四个功能选项
	; ------------------------------------------------------------------
	function_list:
		mov di,160*8+30*2
		; mov ah,04h
		mov cx,4	; 4行功能选项
		mov bx,offset function_address - offset task + 7E00H	; 字符串地址表在内存中的首地址
	show_function_list:
		mov si,[bx]	; 利用字符串地址表找到每行字符串的首地址
		call show_oneline
		add bx,2	; 字符串地址表下一项
		add di,160	; 换行显示
		loop show_function_list
		; 提示信息显示
		mov si,offset tip_1 - offset task + 7E00H
		mov di,160*15+25*2
		call show_oneline
		; 版权信息显示
		mov si,offset tip_0 - offset task + 7E00H
		mov di,160*20+15*2
		call show_oneline
	ret
		
	show_oneline:
	; 这两行放在上面的调用之前就只能显示一行，此处存疑...
		push cx
		push di	
	onelines:
		mov cl,[si]
		mov ch,0
		jcxz show_oneline_ok
		mov es:[di],cl
		mov ch,04h
		mov es:[di+1],ch
		inc si
		add di,2
		jmp short onelines
	show_oneline_ok:
		pop di
		pop cx
	ret
	; ------------------------------------------------------------------
	
	
	taskend:
		nop
	
		
	code ends
	end start