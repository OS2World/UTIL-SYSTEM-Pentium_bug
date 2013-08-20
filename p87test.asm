        .model tiny

        .data
one     dt      1.0
bugnr   dt      824633702449.0
diff    dt      ?               ; Should be 0.0 after testing!

feature_bits dd ?

cpu_msg dw      I808x$, I186$, I286$, I386$, I486$, cpuid5$
ndp_msg dw      No87$, I8087$, I287$, I387$

feature_list dw fpu$, vme$, iobrk$, pse$, tsc$, p5msr$, 0, mce$, cx8$

cprt    db      'Pentium FDIV bug finder.  (c) Terje Mathisen 1994'
        db      13,10,13,10,'$'

I808x$  db      'This is an 808x cpu',13,10,'$'
I186$   db      'This is a 186 cpu',13,10,'$'
I286$   db      'This is a 286 cpu',13,10,'$'
I386$   db      'This is a 386 cpu',13,10,'$'
I486$   db      'This is a 486 cpu',13,10,'$'
cpuid5$ db      'This is a Pentium or better cpu',13,10,'$'

No87$   db      'It has no ndp!',13,10,'$'
I8087$  db      'It has an 8087 ndp',13,10,'$'
I287$   db      'It has a 287 ndp',13,10,'$'
I387$   db      'It has a 387 or later ndp',13,10,'$'

fpu$    db      '  1 : FPU (NDP) onchip',13,10,'$'
vme$    db      '  2 : Virtual 86 Mode Extensions',13,10,'$'
iobrk$  db      '  4 : I/O Breakpoints',13,10,'$'
pse$    db      '  8 : Page Size Extensions',13,10,'$'
tsc$    db      ' 10 : Time Stamp Counter',13,10,'$'
p5msr$  db      ' 20 : Pentium stype MSRs',13,10,'$'
mce$    db      ' 80 : Machine Check Exception',13,10,'$'
cx8$    db      '100 : CMPXCHG8B instruction available',13,10,'$'

earlyP5$ db 'This is an early Pentium, with only partial CPUID support!',13,10,'$'

cpuid_result$   db 13,10,'CPUID reports back:',13,10
        db      'Vendor id = "'
vendor_id dd    3 dup (?)
        db      '"',13,10
        db      'Family (4=486, 5=Pentium etc.) = '
make$   dw      '00'
        db      ', stepping = '
step$   dw      '00'
        db      ', model = '
model$  dw      '00'
        db      13,10,'$'

feature_msg1$ db 13,10,'CPU feature list:',13,10
feature_msg2$ db '$'

FPU_bug$ db     13,10,'It has the FDIV bug:',13,10
   db  '(1.0/824633702449.0)*824633702449.0 is not equal to 1.0!',13,10,'$'

FPU_OK$ db      13,10,'It does not have the FDIV bug!',13,10,'$'

stepping db     ?
CPUModel db     ?
Cpu_Type db     ?       ; 0,1,2,3,4,5 etc
Ndp_Type db     ?       ; None, 8087, 287, 387+
have_cpuid db   0

Notp5$  db      'The FDIV bug occurs only on Pentium cpus!',13,10,'$'

        .code
        org     100h
start   proc    far

        lea     dx,[cprt]
        mov     ah,9
        int     21h

        call    getcpu

        mov     bl,[cpu_type]
        cmp     bl,5
         jbe    @@ok
        mov     bl,5
@@ok:
        xor     bh,bh
        add     bx,bx
        mov     dx,cpu_msg[bx]
        mov     ah,9
        int     21h

        test    [have_cpuid],-1
         jz     no_cpuid

        mov     bx, word ptr [feature_bits]
        mov     ax, word ptr [feature_bits+2]
        or      ax,bx
        lea     dx,[earlyP5$]
         jz     dispMsg

;
; We have full CPUID support on this cpu, report back what we found!
;
        mov     al,[stepping]
        xor     ah,ah
        mov     bl,10
        div     bl
        add     ax,'00'
        mov     [step$],ax

        mov     al,[CpuModel]
        xor     ah,ah
        div     bl
        add     ax,'00'
        mov     [model$],ax

        mov     al,[cpu_type]
        xor     ah,ah
        div     bl
        add     ax,'00'
        mov     [make$],ax
        
        lea     dx,[cpuid_result$]
        mov     ah,9
        int     21h
;
; Display feature bits definitions:
;
        lea     si,[feature_list-2]
        mov     cx,9            ; Nr of defined feature bits
        mov     di,word ptr [feature_bits]

        lea     dx,[feature_msg1$]
        mov     ah,9
        int     21h

@@next_feature:
        add     si,2
        shr     di,1
         jnc    @@skip_feature
        mov     dx,[si]
        mov     ah,9
        int     21h

@@skip_feature:
        dec     cx
         jnz    @@next_feature

        lea     dx,[feature_msg2$]
dispMsg:
        mov     ah,9
        int     21h

no_cpuid:
        call    getndp
        mov     bl,[ndp_type]
        cmp     bl,3
         jbe    @@ndp_ok
        mov     bl,3
@@ndp_ok:
        xor     bh,bh
        add     bx,bx
        mov     dx,ndp_msg[bx]
        mov     ah,9
        int     21h

        test    bx,bx
         jz     exit            ; No NDP, so no NDP bug either! :-)

        call    testndp
        lea     dx,[FPU_OK$]
         jz     @@disp_bug
        lea     dx,[FPU_Bug$]
@@disp_bug:
        mov     ah,9
        int     21h

exit:
        mov     ax,4c00h
        int     21h             ; All done!
start   endp

getcpu  proc    ; return 0,1,2,3,4,5 etc in BL for 808x,186,286,386...

        pushf
        pop     ax
        and     ah,0fh          ; Try to clear four upper flag bits!
        push    ax
        popf
        pushf
        pop     ax
        xor     bx,bx           ; Assume 808x -> BX = 0
        cmp     ah,0f0h
         jae    getcpu_done     ; All four upper bits set -> 808x!

        or      ah,0f0h         ; Try to set the upper four bits:
        push    ax
        popf
        pushf
        pop     ax
        and     ah,0f0h         ; Isolate them
        mov     bx,2            ; This is a 286!
         jz     getcpu_done     ; Just a 286, no FDIV problem!
;
; *************** 386+ code *******************
;
        .486
        mov     edx,esp
        and     esp,not 3               ; DWORD-align ESP!

        pushfd
        pop     eax
        mov     ecx,eax
        xor     ecx,1 SHL 18    ; AC flag == bit # 18!
        push    ecx
        popfd
        pushfd
        pop     ecx
        push    eax
        popfd
        mov     esp,edx

        inc     bx              ; BX = 3
        xor     ecx,eax         ; Could we toggle the AC flag?
         jz     getcpu_done     ; No, so this is a 386!

        mov     ecx,eax
        xor     eax,1 SHL 21    ; ID flag == bit # 21!
        push    eax
        popfd
        pushfd
        pop     eax
        inc     bx              ; BX = 4
        xor     eax,ecx         ; Could we toggle the ID bit?
         jnz    haveCPUID       ;

getcpu_done:
        mov     [cpu_type],bl
        ret                     ; Return with BX = CPU ID

haveCPUID:
        mov     [have_cpuid],1  ; Minimal support for CPUID

; Use CPUID to get more info!
        xor     eax,eax
        db      0Fh, 0A2h       ; CPUID opcode!

        mov     [vendor_id],ebx
        mov     [vendor_id+4],edx
        mov     [vendor_id+8],ecx
        test    eax,eax
         jz     getcpu_done

        mov     eax,1
        db      0Fh, 0A2h       ; CPUID opcode!
        mov     [feature_bits],edx
        and     ah,15           ; CPU Make [4(486), 5 (Pentium) etc]
        mov     [cpu_type],ah   ; Save it! (Return value)

        mov     ah,al
        shr     ah,4
        and     al,15
        mov     [stepping],al
        mov     [CpuModel],ah
        .8086

        ret
getcpu  endp

        .data
cw      dw      ?

        .code

getndp  proc
        fninit
        xor     dx,dx                   ; DL = (NO87, 8087, 287, 387+)
        mov     bx,offset cw
        mov     [bx],dx                 ; Make sure ControlWord is zero!
        fnstcw  [bx]
         jmp    $+2                     ; Wait for result
         jmp    $+2                     ; Wait for result
         jmp    $+2                     ; Wait for result
        cmp     byte ptr [bx+1],03
         jne    ndpdone                 ; NO 87 installed

        fdisi                           ; 8087 Disable interrupts
        fstcw   [bx]
        inc     dx                      ; At least 8087
        fwait                           ;  Wait for result from FSTCW
        test    byte ptr [bx],80h       ; DISI bit set?
         jnz    ndpdone                 ; Yes, it's a 8087

        .286
        .287
        inc    dx                       ; 80287 or 80387
        fld1
        fldz
        fdivp   st(1),st                ; 1/0 = +Inf
        fld     st(0)
        fchs                            ; = -Inf
        fcompp
        fwait                           ; Wait for result
        fstsw   ax
        sahf                            ; Status from float point cmp
         je     ndpdone                 ; +Inf == -Inf => 287
        inc     dx                      ; 387
        .8086
        .8087
ndpdone:
        mov    [ndp_type],dl
        ret

getndp  endp

testndp proc
; Check for FPU bug: Return Z(ero)/NonZero for OK/Bad

        finit
        fld     [one]
        fld     [bugnr]
        fdivp   st(1),st
        fld     [bugnr]
        fmulp   st(1),st
        fld     [one]
        fsubp   st(1),st
        fstp    [diff]
        fwait
        mov     ax,word ptr [diff]
        or      ax,word ptr [diff+2]
        or      ax,word ptr [diff+4]
        ret
testndp endp

        end     start

