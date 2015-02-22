unit Console;

interface

uses
  Classes,
  SysUtils,
  sdl2,
  dglOpenGL;

var
  con_show : Boolean = false;

procedure RenderConsole();
procedure ControlConsole(const key : Integer);
procedure AddConsoleInput(const ch : Char);

implementation

uses
  Renderer,
  Scripting,
  Main,
  Font,
  Log;

var
  con_aniheight   : Integer = 593;
  con_row         : integer;
  con_cursorpos   : integer;
  con_commandrow  : integer;
  con_command     : String;
  con_history     : TStringList;
  con_lasttime    : Integer = 0;
  con_cursortime  : Integer;
  con_showcursor  : Boolean;

procedure Execute(const command : String);
var
  i : Integer;
begin
  if command = '' then exit;
  Print(command);
  If Not(con_history.Find( command, i )) then
    con_history.Add(command);
  Scripting.Execute(con_command);
  con_command := '';
  con_row := log_text.Count-1;
  con_cursorpos := length(con_command)+1;
end;

procedure RenderConsole();
var
  i,j, dt, time, rc, hdiv : Integer;
begin
  //do some timing
  time         := SDL_GetTicks();
  dt           := time - con_lasttime;
  con_lasttime := time;

  //get some stuff
  hdiv := (scr_height div 2)+5;

  //do some animation
  If con_show then
    con_aniheight := con_aniheight - dt * 2
  else
    con_aniheight := con_aniheight + dt * 2;
  if con_aniheight < 0 then
    con_aniheight := 0;
  if con_aniheight > hdiv then
  begin
    con_row       := log_text.Count-1;
    con_cursorpos := length(con_command)+1;
    con_aniheight := hdiv;
    exit;
  end;

  glBlendFunc(GL_SRC_ALPHA, GL_ONE_MINUS_SRC_ALPHA);
  glEnable(GL_BLEND);
  RenderColorQuad(GL_QUADS, 0,hdiv+con_aniheight, scr_width,(scr_height-hdiv)+con_aniheight,0.4,0.4,0.4,0.85 );
  glDisable(GL_BLEND);
  RenderColorQuad(GL_LINE_LOOP, -1,hdiv+con_aniheight, scr_width+5, 20,1,1,1,1 );

  j := 0;
  rc := hdiv div 13;
  StartText();
  for i := con_row downto con_row-rc do
  begin
    If  (i >= 0) then
    begin
      if Pos('Warning:',log_text.strings[i]) > 0 then
        RenderText(log_text.strings[i], 2, (hdiv+con_aniheight+5)+18+(j*13), 0.2, 1,1,0)
      else
        RenderText(log_text.strings[i], 2, (hdiv+con_aniheight+5)+18+(j*13), 0.2);
      j := j + 1;
    end
  end;
  RenderText(con_command, 2, (hdiv+con_aniheight+3), 0.2);

  con_cursortime  := con_cursortime + dt;
  if (con_cursortime >= 500) then
  begin
    con_showcursor := not(con_showcursor);
    con_cursortime := 0;
  end;
  if con_showcursor then
    RenderText('_', TextWidth(Copy(con_command, 1, con_cursorpos-1), 0.2)+2, (hdiv+con_aniheight+2), 0.2);

  EndText();
end;

procedure ControlConsole(const key : Integer);
begin
  If Not(con_show) then exit;
  case key of
  SDL_SCANCODE_PAGEUP    : begin
                             If log_text.count = 0 then exit;
                             con_row := con_row - 1;
                             If con_row < 0 then con_row := 0;
                           end;
  SDL_SCANCODE_PAGEDOWN  : begin
                             If log_text.count = 0 then exit;
                             con_row := con_row + 1;
                             If con_row > log_text.count-1 then con_row := log_text.count-1;
                           end;
  SDL_SCANCODE_UP        : begin
                             If con_history.Count = 0 then exit;
                             con_commandrow := con_commandrow - 1;
                             If con_commandrow < 0 then
                               con_commandrow := con_history.Count-1;
                             con_command :=  con_history.Strings[con_commandrow];
                             con_cursorpos := length(con_command)+1;
                           end;
  SDL_SCANCODE_DOWN      : begin
                             If con_history.count = 0 then exit;
                             con_commandrow := con_commandrow + 1;
                             If con_commandrow > con_history.Count-1 then
                               con_commandrow := 0;
                             con_command :=  con_history.Strings[con_commandrow];
                             con_cursorpos := length(con_command)+1;
                           end;
  SDL_SCANCODE_LEFT      : begin
                             if (con_cursorpos = 1) then exit;
                               con_cursorpos := con_cursorpos - 1
                           end;
  SDL_SCANCODE_RIGHT    :  begin
                             if (con_cursorpos = (length(con_command) + 1)) then exit;
                               con_cursorpos := con_cursorpos + 1
                           end;
  SDL_SCANCODE_BACKSPACE : begin
                             if con_cursorpos = 1 then exit;
                               Delete(con_command, con_cursorpos-1, 1);
                             con_cursorpos := con_cursorpos - 1;
                           end;
  SDL_SCANCODE_RETURN    : Execute(con_command);
  end;
end;

procedure AddConsoleInput(const ch : Char);
begin
  If Not(con_show) then exit;
  If Not(((Ord(ch) >= 32) and (Ord(ch) <= 126))) then Exit;
  If ch = '`' then Exit;
  Insert(ch, con_command, con_cursorpos);
  con_cursorpos := con_cursorpos + 1;
end;

initialization
  con_history := TStringList.Create();
finalization
  FreeAndNil(con_history);
end.
