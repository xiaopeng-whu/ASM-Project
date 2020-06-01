; 在屏幕指定位置显示数据
; 数据即为lab7.asm中的四项数据
; 数据分为两类：字符类（年份）和数字类（收入、人数、人均收入）
; 字符类可以直接显示，数字类需要先转化为字符
; 0.在显示之前还要先清空屏幕
; 1.先求出员工人均年收入（dword除以word，需使用lab10_2.asm的divdw函数），并存在数据段的预留空间中
; 2.指定位置显示年份数据（lab10_1.asm的show_str函数）
; 3.将dword类型数字数据转化为字符串（新的ddtoc函数），在指定位置显示
; 4.将word类型数字数据转化为字符串（lab10_3.asm的dtoc函数），在指定位置显示

assume cs:codesg,ds:data,es:stack
data segment
	; 84字节（0~83） 21*4bytes  年份
	db '1975','1976','1977','1978','1979','1980','1981','1982','1983'
	db '1984','1985','1986','1987','1988','1989','1990','1991','1992'
	db '1993','1994','1995'
	; 84字节（84~167） 21*dword  公司总收入
	dd 16,22,382,1356,2390,8000,16000,24486,50065,97479,140417,197514
	dd 345980,590827,803530,1183000,1843000,2759000,3753000,4649000,5937000
	; 42字节（168~209） 21*word  公司雇员人数
	dw 3,7,9,13,28,38,130,220,476,778,1001,1442,2258,2793,4037,5635,8226
	dw 11542,14430,15257,17800
	; 84字节（210~293） 21*dword  公司员工人均年收入
	dd 21 dup (0)	; 预留21个dword的空间
	; 10字节（294~303）
	db 10 dup (0)	; 存放一个数转化为字符串的空间
data ends

stack segment
	dw 0,0,0,0,0,0,0,0	; 16字节堆栈空间
stack ends

codesg segment
start:
	mov ax,data
	mov ds,ax
	
	mov ax,stack
	mov ss,ax
	mov sp,16
	
	mov ax,0b800h
	mov es,ax ; 存储显示缓冲区首地址的段地址
	
; 0.清屏操作
	call clear_screen
	
	
; 1.计算员工人均年收入
; 已调试成功
	mov si,84	; 总收入数据位置
	mov di,168	; 员工人数数据位置
	sub bx,bx	; 起始设置为0，即数据段起始位置
	mov cx,21
function1:	
	push cx	; 因32位除法使用了cx寄存器，故先压栈保存
	push bx ; 寄存器在调用函数前要保留 经调试（观察也可）发现bx在函数内被改变
	mov ax,ds:[si] 		; 被除数低位
	mov dx,ds:[si+2]	; 被除数高位
	mov cx,ds:[di]		; 除数，cx已经保存入栈，可以用cx存储
	call divdw	; 32位除法防止溢出问题
	; 恢复寄存器
	pop bx
	pop cx
	mov ds:[bx+210],ax	; 结果存在预留空间 低16位
	mov ds:[bx+212],dx	; 高16位
	add si,4	; dword
	add di,2	; word
	add bx,4	; dword
	loop function1

	
; 2.指定位置显示年份数据
; 已调试成功
	mov dh,2	; 行号
	mov dl,5	; 列号
	sub bx,bx	; 通用寄存器太少了，暂时用bx存储颜色属性吧
	mov bl,2	; 颜色  不能使用cl，下面用到了cx会破坏
	mov si,0	; ds:[si]字符串首地址
	mov cx,21	; 这里改变了cl，导致下面错误
function2:
	push cx
	push dx	;同样要保存现场
	push bx
	call show_year	; 指定位置显示年份（4个字符）
	pop bx
	pop dx
	pop cx
	inc dh	; 每行显示一年的数据
	loop function2
	
	
; 3.将dword类型数字数据（总收入和人均年收入）转化为字符串,并在指定位置显示
; 已调试成功
	mov di,84	; 总收入数据位置
	mov dh,2	; 行号
	mov dl,20	; 暂时放在20列
	mov bl,2	; 颜色
	mov cx,21	; 转化21次，每次转化结束后就在指定位置显示
function3_1:
	push cx
	push bx
	push dx
	mov ax,ds:[di]	; dword型数据  被除数低位
	mov dx,ds:[di+2]	; 被除数高位
	; cx作为divdw的除数输入，却在ddtoc中被使用，每次都要在函数最后重新对cx赋值
	mov cx,10	; 除数为10，每次只取最低位（余数）  
	mov si,302	; 从数据段倒数第二个位置开始存储，这样最后结尾符为0 这句也不能在循环里
	call ddtoc
	pop dx
	pop bx
	pop cx
	
	push bx
	push dx
	push cx
	push di	; 注意，di在show_str也被使用需要入栈保存
	call show_str
	pop di
	pop cx
	pop dx
	pop bx
	
	add di,4	; word型数据每次向后移动四个字节（一开始按照word类型写的，被坑死..）
	
	inc dh	; 每行一个数据
	loop function3_1

	mov di,210	; 人均收入数据位置
	mov dh,2	; 行号
	mov dl,50	; 暂时放在50列
	mov cx,21	; 转化21次，每次转化结束后就在指定位置显示
function3_2:
	push cx
	push bx
	push dx
	mov ax,ds:[di]	; dword型数据  被除数低位
	mov dx,ds:[di+2]	; 被除数高位
	; cx作为divdw的除数输入，却在ddtoc中被使用，每次都要在函数最后重新对cx赋值
	mov cx,10	; 除数为10，每次只取最低位（余数）  
	mov si,302	; 从数据段倒数第二个位置开始存储，这样最后结尾符为0 这句也不能在循环里
	call ddtoc
	pop dx
	pop bx
	pop cx
	
	push bx
	push dx
	push cx
	push di	; 注意，di在show_str也被使用需要入栈保存
	call show_str
	pop di
	pop cx
	pop dx
	pop bx
	
	add di,4	; word型数据每次向后移动四个字节（一开始按照word类型写的，被坑死..）
	
	inc dh	; 每行一个数据
	loop function3_2

	
; 4.将word类型数字数据（员工人数）转化为字符串,并在指定位置显示
; 已调试成功
	mov di,168	; 员工人数数据位置
	mov dh,2	; 行号
	mov dl,35	; 暂时放在35列
	mov bl,2	; 颜色
	mov cx,21	; 转化21次，每次转化结束后就在指定位置显示
function4:
	push cx
	push bx
	push dx
	mov ax,ds:[di]	; word型数据  这行语句不能在循环里，只需赋值一次
	mov bx,10	; 除数为10，每次只取最低位（余数）
	mov si,302	; 从数据段倒数第二个位置开始存储，这样最后结尾符为0 这句也不能在循环里
	call dtoc
	pop dx
	pop bx
	pop cx
	
	push bx
	push dx
	push cx
	push di	; 注意，di在show_str也被使用需要入栈保存
	call show_str
	pop di
	pop cx
	pop dx
	pop bx
	
	inc di	; word型数据每次向后移动两个字节
	inc di
	inc dh	; 每行一个数据
	loop function4
		

	mov ax,4c00h
	int 21h

	
; 解决除法溢出问题的子函数
divdw:	
	mov bx,ax	; 保留ax
	mov ax,dx
	sub dx,dx	; 除数为16位，被除数ax存低16位，dx存高16位
	div cx	; ax=int(H/N)作为结果高16位,dx=rem(H/N)因为rem(H/N)*65536相当于高16位
	push ax	; 将结果高位压栈
	mov ax,bx	; [rem(H/N)*65536+L]
	div cx	; ax=结果低16位,dx=结果余数
	push ax ; 将结果低位压栈
	push dx	; 将结果余数压栈
	pop cx	; 余数
	pop	ax	; 结果的低16位
	pop dx	; 结果的高16位
	ret

; 显示字符串（年份）的子函数
show_year:
	sub ax,ax
	mov al,160	; 一行160个字节
	mul dh
	sub dh,dh
	add dl,dl	; 一个字符两个字节
	add ax,dx
	mov di,ax	; 要显示位置的首地址
	
	mov al,bl	; al存放字符属性
	mov cx,4	; 年份占四个字符  这里又使用了cx，导致cl被破坏
n1:	
	mov bl,[si]	; 这里还是修改了bl，故需要将bx在栈中保存
	mov es:[di],bl
	mov es:[di+1],al
	inc si
	add di,2
	loop n1
	ret

; 将word类型数字数据（员工人数）转化为字符串，存在数据段最后
dtoc:
	mov dx,0	; 存储余数
	div bx
	add dx,30H	; 余数转化为ASCII码
	mov ds:[si],dl	; 将ASCII码倒序存入数据段空间中
	
	mov cx,ax	; cx用于jcxz判断
	jcxz break1	; 若商为0，则结束该word数字数据转换过程
	
	dec si	; 每存一个ASCII后前移一位，在ret返回时si指向的是第一个ASCII码
	jmp short dtoc
break1:
	ret
	
; 将dword类型数字数据（总收入和人均年收入）转化为字符串，存在数据段最后
ddtoc:
	; mov bx,0	; 存储余数
	call divdw
	add cx,30H	; 余数转化为ASCII码
	mov ds:[si],cl	; 将ASCII码倒序存入数据段空间中
	
	mov cx,ax	; cx用于jcxz判断
	jcxz break2	; 若商为0，则结束该dword数字数据转换过程
	
	dec si	; 每存一个ASCII后前移一位，在ret返回时si指向的是第一个ASCII码
	mov cx,10	; cx作为除数，经过上述多次值改变后要恢复
	jmp short ddtoc
break2:
	ret
	
; 显示字符串（员工人数）的子函数，根据结尾符0判断是否停止显示
show_str:	
	sub ax,ax
	mov al,160 ;一行160个字节
	mul dh
	sub dh,dh
	add dl,dl ; 一个字符两个字节
	add ax,dx
	mov di,ax ; 存储要显示的位置的首地址
			
	mov al,bl ; al存放字符属性
	sub cx,cx ; jcxz使用
n2:	
	mov cl,[si] 
	jcxz re ; 如果cx为0，则结束打印
	mov es:[di],cl
	mov es:[di+1],al
	inc si
	add di,2
	jmp short n2
re:	
	ret

; 清屏函数
clear_screen:
	mov dl,0
	mov dh,0
	mov bx,0
	mov cx,4000
s:
	mov es:[bx],dx
	add bx,2
	loop s
	ret


codesg ends
end start