unit Skybox;

interface

uses
  SysUtils,
  dglOpenGL,
  Textures,
  Log;

procedure RenderSkyBox();

var
  sky_loaded : boolean = false;
  sky_name   : String = '';

implementation

uses
  Scripting,
  Main;

const
  SKY_BASE      = 'skyboxes/';
  FRONT_TEX     = 'front.tga';
  BACK_TEX      = 'back.tga';
  TOP_TEX       = 'top.tga';
  BOTTOM_TEX    = 'bottom.tga';
  LEFT_TEX      = 'left.tga';
  RIGHT_TEX     = 'right.tga';

var
  sky_has_dpl : boolean = false;
  sky_dpl     : GLuint;

procedure ClearSkyBox();
begin
  if not(sky_loaded) then exit;
  ClearTextures(Params([P(TT_SKYBOX)]));
  glDeleteLists(sky_dpl, 1);
  sky_has_dpl := false;
  sky_loaded := false;
  sky_name := '';
end;

procedure LoadSkybox(const prms : TParams);
begin
  if Not(DirectoryExists(basedatadir + SKY_BASE + prms[0].str)) then
  begin
    Print('Skybox doesn`t excist', LT_WARNING);
    exit;
  end;
  ClearSkyBox();
  sky_name := prms[0].str;
  LoadTexture(Params( [P(TT_SKYBOX), P(SKY_BASE + sky_name + '/' + FRONT_TEX)])); SetWrapMode(GL_CLAMP_TO_EDGE);
  LoadTexture(Params( [P(TT_SKYBOX), P(SKY_BASE + sky_name + '/' + BACK_TEX)])); SetWrapMode(GL_CLAMP_TO_EDGE);
  LoadTexture(Params( [P(TT_SKYBOX), P(SKY_BASE + sky_name + '/' + TOP_TEX)])); SetWrapMode(GL_CLAMP_TO_EDGE);
  LoadTexture(Params( [P(TT_SKYBOX), P(SKY_BASE + sky_name + '/' + BOTTOM_TEX)])); SetWrapMode(GL_CLAMP_TO_EDGE);
  LoadTexture(Params( [P(TT_SKYBOX), P(SKY_BASE + sky_name + '/' + LEFT_TEX)])); SetWrapMode(GL_CLAMP_TO_EDGE);
  LoadTexture(Params( [P(TT_SKYBOX), P(SKY_BASE + sky_name + '/' + RIGHT_TEX)])); SetWrapMode(GL_CLAMP_TO_EDGE);
  sky_loaded := true;
end;

procedure RenderSkyBox();
begin
  if not(sky_loaded) then exit;
  glPushMatrix();
  glTranslatef(player.pos.x, player.pos.y-0.25, player.pos.z);

  if not(sky_has_dpl) then
  begin
    sky_dpl := glGenLists(1);
    glNewList(sky_dpl, GL_COMPILE_AND_EXECUTE);
    glDepthMask(FALSE);
    glColor4f(1,1,1,1);
    glEnable(GL_TEXTURE_2D);

    BindTexture(TT_SKYBOX, 0);
    glBegin(GL_QUADS);
      glTexCoord2f(0.0, 1.0); glVertex3f(-1.0,  1.0, 1.0);
      glTexCoord2f(1.0, 1.0); glVertex3f( 1.0,  1.0, 1.0);
      glTexCoord2f(1.0, 0.0); glVertex3f( 1.0, -1.0, 1.0);
      glTexCoord2f(0.0, 0.0); glVertex3f(-1.0, -1.0, 1.0);
    glend;

    BindTexture(TT_SKYBOX, 1);
    glBegin(GL_QUADS);
      glTexCoord2f(0.0, 0.0); glVertex3f( 1.0, -1.0, -1.0);
      glTexCoord2f(0.0, 1.0); glVertex3f( 1.0,  1.0, -1.0);
      glTexCoord2f(1.0, 1.0); glVertex3f(-1.0,  1.0, -1.0);
      glTexCoord2f(1.0, 0.0); glVertex3f(-1.0, -1.0, -1.0);
    glEnd;

    BindTexture(TT_SKYBOX, 2);
    glBegin(GL_QUADS);
      glTexCoord2f(1.0, 0.0); glVertex3f( 1.0,  1.0, -1.0);
      glTexCoord2f(0.0, 0.0); glVertex3f( 1.0,  1.0,  1.0);
      glTexCoord2f(0.0, 1.0); glVertex3f(-1.0,  1.0,  1.0);
      glTexCoord2f(1.0, 1.0); glVertex3f(-1.0,  1.0, -1.0);
    glEnd;

    BindTexture(TT_SKYBOX, 3);
    glBegin(GL_QUADS);
      glTexCoord2f(1.0, 1.0); glVertex3f(-1.0, -1.0,  1.0);
      glTexCoord2f(1.0, 0.0); glVertex3f( 1.0, -1.0,  1.0);
      glTexCoord2f(0.0, 0.0); glVertex3f( 1.0, -1.0, -1.0);
      glTexCoord2f(0.0, 1.0); glVertex3f(-1.0, -1.0, -1.0);
    glEnd;

    BindTexture(TT_SKYBOX, 4);
    glBegin(GL_QUADS);
      glTexCoord2f(0.0, 0.0); glVertex3f( 1.0, -1.0,  1.0);
      glTexCoord2f(0.0, 1.0); glVertex3f( 1.0,  1.0,  1.0);
      glTexCoord2f(1.0, 1.0); glVertex3f( 1.0,  1.0, -1.0);
      glTexCoord2f(1.0, 0.0); glVertex3f( 1.0, -1.0, -1.0);
    glEnd;

    BindTexture(TT_SKYBOX, 5);
    glBegin(GL_QUADS);
      glTexCoord2f(0.0, 1.0); glVertex3f(-1.0,  1.0, -1.0);
      glTexCoord2f(1.0, 1.0); glVertex3f(-1.0,  1.0,  1.0);
      glTexCoord2f(1.0, 0.0); glVertex3f(-1.0, -1.0,  1.0);
      glTexCoord2f(0.0, 0.0); glVertex3f(-1.0, -1.0, -1.0);
    glEnd();

    glDepthMask(TRUE);
    glDisable(GL_TEXTURE_2D);
    glEndList();
    sky_has_dpl := true;
  end
  else
    glCallList(sky_dpl);

  glPopMatrix();
end;

initialization
  RegProc('clearskybox', @ClearSkyBox);
  RegProc('loadskybox', @LoadSkybox, Params([P(T_STR)]));
finalization
end.
