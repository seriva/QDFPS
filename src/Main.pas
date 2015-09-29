unit Main;

interface

uses
  Math,
  SysUtils,
  sdl2,
  dglOpenGL,
  Map,
  Editing,
  Physics,
  Common,
  Renderer;

type
  TPlayer = record
    pos  : TVecf;
    rot  : TVecf;
    view : TVecf;
    move   : single;
    strafe : single;
    speed  : single;
  end;

var
  window          : PSDL_Window;
  glcontext       : TSDL_GLContext;
  videoflags      : Uint32;
  keystate        : array[0..255] of integer;
  scr_width       : Integer = 800;
  scr_height      : Integer = 600;
  scr_bpp         : Integer = 32;
  scr_fullscreen  : Boolean = false;
  i_forward       : Integer = SDL_SCANCODE_W;
  i_backward      : Integer = SDL_SCANCODE_S;
  i_left          : Integer = SDL_SCANCODE_A;
  i_right         : Integer = SDL_SCANCODE_D;
  m_inverse       : Boolean = false;
  m_sensitivity   : Single = 5.0;
  quit            : Boolean = false;
  basedir         : String;
  basedatadir     : String;
  fpscount        : Integer;
  fps             : Integer;
  player          : TPlayer;
  curtime         : Integer;
  timediff        : Integer;
  frametime       : Single;
  leftdown        : Boolean = false;
  rightdown       : Boolean = false;

procedure RunApp();
procedure QuitApp();

implementation

uses
  Console,
  Scripting,
  Textures,
  Log;

const
  WINDOW_CAPTION = 'QDFPS';
  BASE_SETTINGS  = 'scripts/settings.script';
  BASE_RESOURCES = 'scripts/resources.script';

function FpsTimer(interval: UInt32; param: Pointer): UInt32; cdecl;
begin;
  fps := fpscount;
  SDL_SetWindowTitle(window, PAnsiChar( AnsiString(WINDOW_CAPTION) + ' - ['+IntToStr(Round(fps))+' FPS]'));
  FPSCount := 0;
  Result := 1000;
end;

procedure ProcessKeys();
var
  x, y, z, spd : Single;
begin
  if con_show then exit;

  player.move := 0; player.strafe := 0;
  if (keystate[i_forward] = 1) then player.move := 1;
  if (keystate[i_backward] = 1) then player.move := -1;
  if (keystate[i_left] = 1) then player.strafe := 1;
  if (keystate[i_right] = 1) then player.strafe := -1;

  player.view.x := cos(DegToRad(player.rot.x-90)) * cos(DegToRad(player.rot.y));
  player.view.y := sin(DegToRad(player.rot.y));
  player.view.z := sin(DegToRad(player.rot.x-90)) * cos(DegToRad(player.rot.y));

  x := player.move * player.view.x;
  y := player.move * player.view.y;
  z := player.move * player.view.z;
  x := x + (player.strafe*cos(DegToRad(player.rot.x-180)));
  z := z + (player.strafe*sin(DegToRad(player.rot.x-180)));

  spd := player.speed * frametime;
  player.pos.x := player.pos.x + (x * spd);
  player.pos.y := player.pos.y + (y * spd);
  player.pos.z := player.pos.z + (z * spd);
end;

procedure HandleKeyDown( keysym : TSDL_keysym );
begin
  case keysym.scancode of
    SDL_SCANCODE_ESCAPE : quit := True;
    SDL_SCANCODE_GRAVE  : begin
                            con_show := not(con_show);
                            SDL_ShowCursor(Integer(con_show));
                            if con_show then
                               SDL_StartTextInput()
                            else
                               SDL_StopTextInput();
                          end;
    SDL_SCANCODE_1      : editmode := EM_GEOMETRY;
    SDL_SCANCODE_2      : editmode := EM_TEXTURING;
  end;
  ControlConsole(keysym.scancode);
  keystate[keysym.sym] := 1;
end;

procedure HandleKeyUp( keysym : TSDL_keysym );
begin;
  keystate[keysym.sym] := 0;
end;

procedure HandleMouse(event : TSDL_MouseMotionEvent);
const
  SENSF = 33.0;
  MAXPITCH = 90.0;
var
  dx, dy : Integer;
  inv : Single;
begin
  if con_show then exit;
  dx := event.x - (scr_width div 2);
  dy := event.y - (scr_height div 2);
  if m_inverse then inv := -1 else inv := 1;

  player.rot.x := player.rot.x + ((dx/SENSF) * m_sensitivity);
  player.rot.y := player.rot.y - (((dy/SENSF) * m_sensitivity) * inv);
  if player.rot.y>MAXPITCH  then player.rot.y := MAXPITCH;
  if player.rot.y<-MAXPITCH then player.rot.y := -MAXPITCH;
  if player.rot.x<0 then   player.rot.x := 360;
  if player.rot.x>360 then player.rot.x := 0;
  SDL_WarpMouseInWindow(window, scr_width div 2, scr_height div 2);
end;

procedure HandleMouseButtons(event : TSDL_MouseButtonEvent);
begin
  if con_show then exit;
  case event.button of
    SDL_BUTTON_LEFT  : LeftMouseEdit();
    SDL_BUTTON_RIGHT : RightMouseEdit();
  end;
end;

procedure HandleMouseWheel(event : TSDL_MouseWheelEvent);
begin
  if con_show then exit;
  if event.y > 0 then NextTexture();
  if event.y < 0 then PreviousTexture();
end;

procedure HandleWindow(event : TSDL_WindowEvent);
begin
  case event.event of
    SDL_WINDOWEVENT_RESIZED:
    begin
      scr_width  := event.data1;
      scr_height := event.data2;
      ResizeOGL();
    end;
  end;
end;

procedure HandleEvents();
var
  event : TSDL_Event;
begin;
  while ( SDL_PollEvent( @event ) = 1 ) do
  begin
    case event.type_ of
      SDL_QUITEV          : quit := True;
      SDL_KEYDOWN         : HandleKeyDown(event.key.keysym);
      SDL_KEYUP           : HandleKeyUp(event.key.keysym);
      SDL_MOUSEMOTION     : HandleMouse(event.motion);
      SDL_MOUSEBUTTONDOWN : HandleMouseButtons(event.button);
      SDL_MOUSEWHEEL      : HandleMouseWheel(event.wheel);
      SDL_WINDOWEVENT     : HandleWindow(event.window);
      SDL_TEXTINPUT       : AddConsoleInput(event.text.text[0]);
    end;
  end;
end;

procedure InitApp;
var
  version : TSDL_Version;
begin;
  basedir := ExtractFilePath(ParamStr(0));
  basedatadir := basedir + 'data/';
  ExecuteScript(Params([P(BASE_SETTINGS)]));

  //init sdl
  Print('Initialize SDL...');
  if ( SDL_Init( SDL_INIT_VIDEO or SDL_INIT_TIMER) < 0 ) then
    Print(String(SDL_GetError()), LT_ERROR);

  //get version
  SDL_GetVersion(@version);
  Print( '  Version: ' + IntToStr(version.major) + '.' +
                         IntToStr(version.minor) + '.' +
                         IntToStr(version.patch));

  //create window
  Print('Creating window...');
  videoFlags := SDL_WINDOW_OPENGL or SDL_WINDOW_RESIZABLE;
  if scr_fullscreen then videoFlags := videoFlags or SDL_WINDOW_FULLSCREEN;
  window := SDL_CreateWindow(PAnsiChar(WINDOW_CAPTION), SDL_WINDOWPOS_CENTERED, SDL_WINDOWPOS_CENTERED, scr_width, scr_height, videoFlags);
  if window = nil then
     Print(String(SDL_GetError()), LT_ERROR);

  //create context
  Print('Creating OGL context...');
  SDL_GL_SetAttribute( SDL_GL_RED_SIZE, 8 );
  SDL_GL_SetAttribute( SDL_GL_GREEN_SIZE, 8 );
  SDL_GL_SetAttribute( SDL_GL_BLUE_SIZE, 8 );
  SDL_GL_SetAttribute( SDL_GL_DEPTH_SIZE, 24 );
  SDL_GL_SetAttribute( SDL_GL_DOUBLEBUFFER, 1 );
  glcontext := SDL_GL_CreateContext(window);

  //other stuff
  SDL_AddTimer(1000, @FpsTimer, nil);
  SDL_ShowCursor(0);
  curtime := SDL_GetTicks();
  SDL_WarpMouseInWindow(window, scr_width div 2, scr_height div 2);

  //init opengl
  InitOGL();

  //load base resources
  ExecuteScript(Params([P(BASE_RESOURCES)]));

  //player settings
  player.speed := 7;

  //load the demo map.
  //NewMap(Params([P(256)]));
  loadmap(Params([P('demo')]));
end;

procedure QuitApp;
begin
  ClearMap(0);
  ClearAllTextures();
  SDL_ShowCursor(1);
  SDL_GL_DeleteContext(glcontext);
  SDL_DestroyWindow(window);
  SDL_Quit();
end;

procedure RunApp();
begin
  InitApp();
  while not(quit) do
  begin
    timediff := SDL_GetTicks() - curtime;
    frametime := timediff / 1000.0;
    curtime := SDL_GetTicks();
    HandleEvents();
    ProcessKeys();
    SphereLevelCollision(player.pos, 0.3);
    DoSelection();
    RenderFrame();
    Inc(fpscount);
  end;
  QuitApp();
end;

procedure Exit();
begin
 quit:= true;
end;

initialization
  RegVar('scr_width', T_INT, @scr_width);
  RegVar('scr_height', T_INT, @scr_height);
  RegVar('scr_bpp', T_INT, @scr_bpp);
  RegVar('scr_fullscreen', T_BOOL, @scr_fullscreen);
  RegVar('i_backward', T_INT, @i_backward);
  RegVar('i_forward', T_INT, @i_forward);
  RegVar('i_left', T_INT, @i_left);
  RegVar('i_right', T_INT, @i_right);
  RegVar('m_sensitivity', T_FLOAT, @m_sensitivity);
  RegVar('m_inverse', T_BOOL, @m_inverse);
  RegProc('Exit', @Exit);
finalization
end.
