unit usimd_scanner;

{$mode objfpc}{$H+}
{$ASMMODE INTEL}
{$C-} // Assertions off
{$R-} // Range checking off
{$Q-} // Overflow checking off

interface

uses
  SysUtils;

type
  { Core scanning function signatures }
  
  { Fast-forwards P past the string content, stopping at the unescaped closing quote.
    P is expected to point to the character AFTER the opening quote. 
    Returns the new pointer position pointing exactly at the closing quote. }
  TSkipStringFunc = function(P: PByte; EndPtr: PByte): PByte;

  { Fast-forwards P past whitespace.
    Returns the pointer to the first non-whitespace character. }
  TSkipWhitespaceFunc = function(P: PByte; EndPtr: PByte): PByte;

var
  { Active function pointers set during initialization based on CPU capabilities }
  FastSkipString: TSkipStringFunc;
  FastSkipWhitespace: TSkipWhitespaceFunc;
  FastSkipString16LE: TSkipStringFunc;
  FastSkipWhitespace16LE: TSkipWhitespaceFunc;
  FastSkipString16BE: TSkipStringFunc;
  FastSkipWhitespace16BE: TSkipWhitespaceFunc;

{ Initialize the scanner, detecting CPU capabilities and wiring the function pointers }
procedure InitSIMDScanner;

implementation

{ ── Scalar Fallback Implementations ───────────────────────────────── }

{ The scalar fallback is written to optimize CPU branch prediction by checking
  for escaped characters out-of-band rather than branching inside the core loop. }
function ScalarSkipString(P: PByte; EndPtr: PByte): PByte;
var
  Curr: PByte;
begin
  Curr := P;
  while Curr < EndPtr do
  begin
    case Curr^ of
      Byte('"'):
        // Found end of string
        Exit(Curr);
        
      Byte('\'):
        // Skip over the escaped character to prevent falsely matching \"
        if Curr + 1 < EndPtr then
          Inc(Curr, 2)
        else
          Exit(Curr); // Return pointer to \ so the parser can handle the boundary
    else
      // Fast path, just advance
      Inc(Curr);
    end;
  end;
  Result := Curr;
end;

function ScalarSkipWhitespace(P: PByte; EndPtr: PByte): PByte;
var
  Curr: PByte;
begin
  Curr := P;
  // Space (32), Tab (9), LF (10), CR (13)
  while (Curr < EndPtr) and ((Curr^ = 32) or (Curr^ = 9) or (Curr^ = 10) or (Curr^ = 13)) do
    Inc(Curr);
  Result := Curr;
end;

function ScalarSkipWhitespace16LE(P: PByte; EndPtr: PByte): PByte;
var
  Curr: PByte;
  Ch: Byte;
begin
  Curr := P;
  while Curr + 1 < EndPtr do
  begin
    if (Curr + 1)^ = 0 then
    begin
      Ch := Curr^;
      if (Ch = 32) or (Ch = 9) or (Ch = 10) or (Ch = 13) then
        Inc(Curr, 2)
      else
        Break;
    end
    else
      Break;
  end;
  Result := Curr;
end;

function ScalarSkipString16LE(P: PByte; EndPtr: PByte): PByte;
var
  Curr: PByte;
begin
  Curr := P;
  while Curr + 1 < EndPtr do
  begin
    if (Curr + 1)^ = 0 then
    begin
      case Curr^ of
        Byte('"'): Exit(Curr);
        Byte('\'):
        begin
          if Curr + 3 < EndPtr then
            Inc(Curr, 4)
          else
            Exit(Curr);
        end;
      else
        Inc(Curr, 2);
      end;
    end
    else
      Inc(Curr, 2);
  end;
  Result := Curr;
end;

function ScalarSkipWhitespace16BE(P: PByte; EndPtr: PByte): PByte;
var
  Curr: PByte;
  Ch: Byte;
begin
  Curr := P;
  while Curr + 1 < EndPtr do
  begin
    if Curr^ = 0 then
    begin
      Ch := (Curr + 1)^;
      if (Ch = 32) or (Ch = 9) or (Ch = 10) or (Ch = 13) then
        Inc(Curr, 2)
      else
        Break;
    end
    else
      Break;
  end;
  Result := Curr;
end;

function ScalarSkipString16BE(P: PByte; EndPtr: PByte): PByte;
var
  Curr: PByte;
begin
  Curr := P;
  while Curr + 1 < EndPtr do
  begin
    if Curr^ = 0 then
    begin
      case (Curr + 1)^ of
        Byte('"'): Exit(Curr);
        Byte('\'):
        begin
          if Curr + 3 < EndPtr then
            Inc(Curr, 4)
          else
            Exit(Curr);
        end;
      else
        Inc(Curr, 2);
      end;
    end
    else
      Inc(Curr, 2);
  end;
  Result := Curr;
end;

{$IFDEF CPUX86_64}
{ ── AVX2 Implementations (x86_64) ─────────────────────────────────── }

function AVX2SkipWhitespace(P: PByte; EndPtr: PByte): PByte; assembler; nostackframe;
asm
  // RCX = P, RDX = EndPtr
  // Returns RAX = Curr
  mov rax, rcx
  
@check_end:
  cmp rax, rdx
  jae @done
  
  // Fast path for 32 bytes at a time
  mov r8, rdx
  sub r8, rax
  cmp r8, 32
  jb @scalar_loop // Fallback to scalar if less than 32 bytes
  
  // Load 32 bytes
  vmovdqu ymm0, [rax]
  
  // Compare against space, tab, CR, LF
  // ymm1 = space (32)
  // ymm2 = tab (9)
  // ymm3 = LF (10)
  // ymm4 = CR (13)
  
  // Setup broadcast registers
  mov r9, 32
  vmovd xmm1, r9d
  vpbroadcastb ymm1, xmm1
  
  mov r9, 9
  vmovd xmm2, r9d
  vpbroadcastb ymm2, xmm2
  
  mov r9, 10
  vmovd xmm3, r9d
  vpbroadcastb ymm3, xmm3
  
  mov r9, 13
  vmovd xmm4, r9d
  vpbroadcastb ymm4, xmm4
  
@avx_loop:
  // Check for spaces
  vpcmpeqb ymm5, ymm0, ymm1
  
  // Check for tabs
  vpcmpeqb ymm6, ymm0, ymm2
  vpor ymm5, ymm5, ymm6
  
  // Check for LF
  vpcmpeqb ymm6, ymm0, ymm3
  vpor ymm5, ymm5, ymm6
  
  // Check for CR
  vpcmpeqb ymm6, ymm0, ymm4
  vpor ymm5, ymm5, ymm6
  
  // Create mask of all whitespace characters
  vpmovmskb r9d, ymm5
  
  // If mask is $FFFFFFFF, all 32 chars are whitespace
  cmp r9d, $FFFFFFFF
  jne @found_non_ws
  
  // All whitespace, advance 32 bytes
  add rax, 32
  
  // Check if we still have 32 bytes left
  mov r8, rdx
  sub r8, rax
  cmp r8, 32
  jb @scalar_loop
  
  // Load next 32 bytes
  vmovdqu ymm0, [rax]
  jmp @avx_loop

@found_non_ws:
  // Not all characters are whitespace. Find the first non-whitespace.
  // r9d contains 1 for whitespace, 0 for non-whitespace.
  // We want to find the first 0.
  not r9d
  bsf r9d, r9d
  add rax, r9
  vzeroupper
  ret
  
@scalar_loop:
  vzeroupper
  // Standard scalar loop for remainder
@scalar_inner:
  cmp rax, rdx
  jae @done
  movzx r8, byte ptr [rax]
  cmp r8, 32
  je @next
  cmp r8, 9
  je @next
  cmp r8, 10
  je @next
  cmp r8, 13
  jne @done
@next:
  inc rax
  jmp @scalar_inner
  
@done:
  // RAX already contains the result pointer
end;

function AVX2SkipString(P: PByte; EndPtr: PByte): PByte; assembler; nostackframe;
asm
  // RCX = P, RDX = EndPtr
  // Returns RAX = Curr
  mov rax, rcx
  
@check_end:
  cmp rax, rdx
  jae @done
  
  // Broadcast quote and backslash
  mov r9, 34 // '"'
  vmovd xmm1, r9d
  vpbroadcastb ymm1, xmm1
  
  mov r9, 92 // '\'
  vmovd xmm2, r9d
  vpbroadcastb ymm2, xmm2

@check_len:
  mov r8, rdx
  sub r8, rax
  cmp r8, 32
  jb @scalar_loop
  
@avx_loop:
  // Load 32 bytes
  vmovdqu ymm0, [rax]
  
  // Find quotes
  vpcmpeqb ymm3, ymm0, ymm1
  vpmovmskb r8d, ymm3
  
  // Find backslashes
  vpcmpeqb ymm4, ymm0, ymm2
  vpmovmskb r9d, ymm4
  
  // Are there any quotes or backslashes?
  or r8d, r9d
  jnz @found_quote_or_bs
  
  // Neither found, safely skip 32 bytes
  add rax, 32
  
  mov r10, rdx
  sub r10, rax
  cmp r10, 32
  jae @avx_loop
  jmp @scalar_loop
  
@found_quote_or_bs:
  bsf r8d, r8d
  add rax, r8
  
  // Is it a quote?
  cmp byte ptr [rax], 34
  je @done_vzeroupper
  
  // It's a backslash. Check if we have room for the escaped char.
  mov r11, rax
  inc r11
  cmp r11, rdx
  jae @done_vzeroupper // Return rax pointing to '\'
  
  // Safe to skip both
  add rax, 2
  jmp @check_len
  
@scalar_loop:
  vzeroupper
@scalar_inner:
  cmp rax, rdx
  jae @done
  
  movzx r8, byte ptr [rax]
  cmp r8, 34 // '"'
  je @done
  
  cmp r8, 92 // '\'
  jne @next
  
  // Handle escape boundary
  mov r11, rax
  inc r11
  cmp r11, rdx
  jae @done // Return rax pointing to '\'
  
  add rax, 2
  jmp @scalar_inner
  
@next:
  inc rax
  jmp @scalar_inner
  
@done_vzeroupper:
  vzeroupper
@done:
  // RAX contains result
end;
{$ENDIF}

{$IFDEF CPUX86_64}
function CPUHasAVX2: Boolean; assembler; nostackframe;
asm
  push rbx
  push rcx
  push rdx

  mov eax, 0
  cpuid
  cmp eax, 7
  jb @no_avx2

  mov eax, 7
  xor ecx, ecx
  cpuid

  // AVX2 is bit 5 of ebx
  test ebx, 32
  jz @no_avx2

  mov eax, 1
  jmp @done

@no_avx2:
  xor eax, eax

@done:
  pop rdx
  pop rcx
  pop rbx
end;
{$ENDIF}

{ ── Initialization ────────────────────────────────────────────────── }

procedure InitSIMDScanner;
begin
  { Default to scalar fallbacks }
  FastSkipString := @ScalarSkipString;
  FastSkipWhitespace := @ScalarSkipWhitespace;
  
  FastSkipString16LE := @ScalarSkipString16LE;
  FastSkipWhitespace16LE := @ScalarSkipWhitespace16LE;
  FastSkipString16BE := @ScalarSkipString16BE;
  FastSkipWhitespace16BE := @ScalarSkipWhitespace16BE;

  {$IFDEF CPUX86_64}
  if CPUHasAVX2 then
  begin
    FastSkipString := @AVX2SkipString;
    FastSkipWhitespace := @AVX2SkipWhitespace;
  end;
  {$ENDIF}
end;

initialization
  InitSIMDScanner;

end.
