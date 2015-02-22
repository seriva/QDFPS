unit Renderer;

interface

uses
  SysUtils,
  Log,
  Map,
  sdl2,
  dglOpenGL;

procedure InitOGL();
procedure ResizeOGL();
procedure RenderFrame();

procedure StartProgress(const title: String; const max : integer);
procedure UpdateProgress(const step : Integer);
procedure EndProgress();

procedure RenderColorQuad(const mode: GLenum; const x,y,width,height,r,g,b,a : Single);
procedure RenderTexturedQuad(const x,y,width,height: Single;
                             const u1 : Single=0; const v1 : Single=0;
                             const u2 : Single=1; const v2 : Single=0;
                             const u3 : Single=1; const v3 : Single=1;
                             const u4 : Single=0; const v4 : Single=1);

var
  r_fov  : Single = 45.0;
  r_near : Single = 0.1;
  r_far  : Single = 100.0;
  r_wireframe : Boolean = false;
  r_bounds : Boolean = false;

implementation

uses
  Main,
  Console,
  Scripting,
  Skybox,
  Font,
  Editing,
  Textures,
  Frustum;

procedure InitOGL();
begin
  Print('Initialize OGL...');

  //init ogl
  InitOpenGL;
  ReadExtensions;
  Print( '  Vendor: ' + String(AnsiString(glGetString(GL_VENDOR))));
  Print( '  Renderer: ' + String(AnsiString(glGetString(GL_RENDERER))));
  Print( '  Version: ' + String(AnsiString(glGetString(GL_VERSION))));

  //init states
  glEnable(GL_TEXTURE_2D);
  glClearColor(0,0,0,0);
  glDepthFunc(GL_LESS);
  glClearDepth(1.0);
  glEnable(GL_DEPTH_TEST);
  glCullFace(GL_BACK);
  glEnable(GL_CULL_FACE);
  glHint(GL_PERSPECTIVE_CORRECTION_HINT, GL_NICEST);
end;

procedure ResizeOGL();
begin
  if ( scr_height = 0 ) then scr_height := 1;
  glViewport( 0, 0, scr_width, scr_height );
end;

procedure SetPerspective();
begin
  glMatrixMode( GL_PROJECTION );
  glLoadIdentity;
  gluPerspective( r_fov, scr_width / scr_height, r_near, r_far );
  glMatrixMode( GL_MODELVIEW );
  glLoadIdentity;
end;

procedure SetOrtho(const width, height: integer);
begin
  glMatrixMode( GL_PROJECTION );
  glLoadIdentity;
  glOrtho( 0, width, 0, height, -1, 1 );
  glMatrixMode( GL_MODELVIEW );
  glLoadIdentity;
end;

procedure TranslatePlayer();
begin
  glLoadIdentity();
  glRotated(player.rot.z,0.0,0.0,1.0);
  glRotated(player.rot.y,-1.0,0.0,0.0);
  glRotated(player.rot.x,0.0,1.0,0.0);
  glTranslatef(-player.pos.x, -player.pos.y, -player.pos.z);
  CalculateFrustum();
end;

procedure CheckGLErrors();
var
 iError : Integer;
begin
  iError := glGetError();
  case iError of
    GL_NO_ERROR          : ;
    GL_INVALID_ENUM      : Print('Invalid operation found', LT_WARNING);
    GL_INVALID_VALUE     : Print('Invalid value found', LT_WARNING);
    GL_INVALID_OPERATION : Print('Stack overflow found', LT_WARNING);
    GL_STACK_OVERFLOW    : Print('Stack underflow found', LT_WARNING);
    GL_STACK_UNDERFLOW   : Print('Incomplete attachment', LT_WARNING);
    GL_OUT_OF_MEMORY     : Print('Stack out of memory', LT_WARNING);
    GL_TABLE_TOO_LARGE   : Print('Table too large', LT_WARNING);
  end;
end;

procedure RenderCrosshair();
var
  x, y : Single;
begin
  x := (scr_width / 2)-20;
  y := (scr_height / 2)-20;
  glEnable(GL_BLEND);
  glBlendFunc(GL_ONE, GL_ONE);
  glEnable(GL_TEXTURE_2D);
  BindTexture(TT_GLOBAL, 1);
  RenderTexturedQuad(x,y,40,40);
  glDisable(GL_TEXTURE_2D);
  glDisable(GL_BLEND);
end;

var
   progress_current, progress_max : integer;
   progress_title : String;

procedure StartProgress(const title: String; const max : integer);
begin
  progress_current := 0;
  progress_max := max;
  progress_title := title;
  glDisable(GL_TEXTURE_2D);
  glDisable(GL_DEPTH_TEST);
  glClearColor(0,0,0,0);
  SetOrtho(800, 600);
  UpdateProgress(0);
end;

procedure EndProgress();
begin

end;

procedure UpdateProgress(const step : Integer);
var
  i : Integer;
begin
  progress_current := progress_current + step;
  glClear( GL_COLOR_BUFFER_BIT or GL_DEPTH_BUFFER_BIT );

  i := Round(progress_current * (300/progress_max));
  glBlendFunc(GL_SRC_ALPHA, GL_ONE_MINUS_SRC_ALPHA);
  glEnable(GL_BLEND);
  RenderColorQuad(GL_QUADS, 240,265,320,65,0.4,0.4,0.4,0.85 );
  glDisable(GL_BLEND);
  RenderColorQuad(GL_QUADS, 250,275,i,30 ,0, 0, 1, 1 );
  RenderColorQuad(GL_LINE_LOOP, 250,275,300,30 ,1, 1, 1, 1 );
  RenderColorQuad(GL_LINE_LOOP, 240,265,320,65,1,1,1,1 );
  RenderTextOne(progress_title, 248, 312, 0.175);

  SDL_GL_SwapWindow(window);
end;

procedure RenderColorQuad(const mode: GLenum; const x,y,width,height,r,g,b,a : Single);
begin
  glColor4f(r,g,b,a);
  glBegin(mode);
    glVertex2f(x,y+height);
    glVertex2f(x,y);
    glVertex2f(x+width,y);
    glVertex2f(x+width,y+height);
  glEnd();
end;

procedure RenderTexturedQuad(const x,y,width,height: Single;
                             const u1 : Single=0; const v1 : Single=0;
                             const u2 : Single=1; const v2 : Single=0;
                             const u3 : Single=1; const v3 : Single=1;
                             const u4 : Single=0; const v4 : Single=1);
begin
  glBegin(GL_QUADS);
    glTexCoord2f(u1, v1); glVertex2f( x,       y);
    glTexCoord2f(u2, v2); glVertex2f( x+width, y);
    glTexCoord2f(u3, v3); glVertex2f( x+width, y+height);
    glTexCoord2f(u4, v4); glVertex2f( x,       y+height);
  glEnd();
end;

procedure RenderWireFrame();
begin
  if not(r_wireframe) then exit;
  glColor3f(1,1,1);
  glDepthFunc(GL_LEQUAL);
  glPolygonMode(GL_FRONT, GL_LINE);
  RenderMap(RM_WIREFRAME);
  glPolygonMode(GL_FRONT, GL_FILL);
  glDepthFunc(GL_LESS);
end;

procedure RenderBounds();
begin
  if not(r_bounds) then exit;
  glDisable(GL_DEPTH_TEST);
  glColor3f(1,1,0);
  RenderMap(RM_NODEBOUNDS);
  glEnable(GL_DEPTH_TEST);
end;

procedure RenderFrame();
begin
  glClearColor(0,0,0,0);
  glClear( GL_COLOR_BUFFER_BIT or GL_DEPTH_BUFFER_BIT );
  SetPerspective();
  TranslatePlayer();

  RenderSkyBox();
  glEnable(GL_TEXTURE_2D);
  glEnable(GL_DEPTH_TEST);
  RenderMap(RM_NORMAL);
  glDisable(GL_TEXTURE_2D);

  RenderWireFrame();
  RenderBounds();
  RenderEditingTool();

  SetOrtho(scr_width, scr_height);
  glDisable(GL_DEPTH_TEST);
  RenderEditingInterface();
  RenderCrosshair();
  RenderConsole();

  SDL_GL_SwapWindow(window);
  CheckGLErrors();
end;

initialization
  RegVar('r_fov', T_FLOAT, @r_fov);
  RegVar('r_near', T_FLOAT, @r_near);
  RegVar('r_far', T_FLOAT, @r_far);
  RegVar('r_wireframe', T_BOOL, @r_wireframe);
  RegVar('r_bounds', T_BOOL, @r_bounds);
finalization
end.

