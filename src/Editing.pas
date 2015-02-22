unit Editing;

interface

uses
  SysUtils,
  Textures,
  Common,
  dglOpenGL;

procedure LeftMouseEdit();
procedure RightMouseEdit();
procedure DoSelection();
procedure NextTexture();
procedure PreviousTexture();
procedure RenderEditingTool();
procedure RenderEditingInterface();
procedure ResetEditing();

type
  TEditMode = (EM_NONE, EM_GEOMETRY, EM_TEXTURING);

var
  editmode : TEditMode = EM_GEOMETRY;

implementation

uses
  Map,
  Main,
  Frustum,
  Font,
  Physics,
  Renderer;

var
  sel_start, sel_new : TVeci;
  sel_hits_new, sel_hits_start : boolean;
  sel_side : integer = 0;
  sel_tex : integer = 0;
  ci : TCollisionInfo;

procedure RenderEditingTool();

  procedure RenderSelSide(const p : TVeci; const side: integer);
  begin
    glBegin(GL_QUADS);
      glVertex3f( VERT[side][1][1]+p.x, VERT[side][1][2]+p.y, VERT[side][1][3]+p.z);
      glVertex3f( VERT[side][2][1]+p.x, VERT[side][2][2]+p.y, VERT[side][2][3]+p.z);
      glVertex3f( VERT[side][3][1]+p.x, VERT[side][3][2]+p.y, VERT[side][3][3]+p.z);
      glVertex3f( VERT[side][4][1]+p.x, VERT[side][4][2]+p.y, VERT[side][4][3]+p.z);
    glEnd();
  end;

  procedure RenderSelCube(const p : TVeci);
  var
    i : integer;
  begin
    for i := 1 to 6 do
      RenderSelSide(p, i);
  end;

begin
  if not(sel_hits_start) then exit;

  case editmode of
    EM_GEOMETRY  :
    begin
      //render delete block
      glDisable(GL_DEPTH_TEST);
      glBlendFunc(GL_SRC_ALPHA, GL_ONE_MINUS_SRC_ALPHA);
      glEnable(GL_BLEND);
      glColor4f(1.0, 0.0, 0.0, 0.4);
      RenderSelCube(sel_start);
      glDisable(GL_BLEND);
      glLineWidth(2);
      glColor4f(0.8, 0.0, 0.0, 1.0);
      glPolygonMode(GL_FRONT_AND_BACK, GL_LINE);
      RenderSelCube(sel_start);

      //render add block
      if sel_hits_new then
      begin
        glEnable(GL_LINE_STIPPLE);
        glDisable(GL_CULL_FACE);
        glLineStipple(1, $00FF);
        glColor4f(0.0, 0.8, 0.0, 1.0);
        RenderSelCube(sel_new);
        glEnable(GL_CULL_FACE);
        glDisable(GL_LINE_STIPPLE);
      end;

      glPolygonMode(GL_FRONT_AND_BACK, GL_FILL);
      glLineWidth(1);
      glEnable(GL_DEPTH_TEST);
    end;
    EM_TEXTURING :
    begin
      //render the texture side.
      glDisable(GL_DEPTH_TEST);
      glBlendFunc(GL_SRC_ALPHA, GL_ONE_MINUS_SRC_ALPHA);
      glEnable(GL_BLEND);
      glColor4f(0.0, 1.0, 0.0, 0.3);
      RenderSelSide(sel_start, sel_side);
      glPolygonMode(GL_FRONT_AND_BACK, GL_LINE);
      glColor4f(0.0, 1.0, 0.0, 1.0);
      RenderSelSide(sel_start, sel_side);
      glPolygonMode(GL_FRONT_AND_BACK, GL_FILL);
    end;
  end;
end;

procedure DoSelection();
var
  sp : TVeci;
begin
  sel_hits_new   := false;
  sel_hits_start := false;

  //select editing cube and selection side
  ci := RayCast(player.pos, player.view, 64);
  if not(ci.collided) then exit;

  sel_start := Veci(ci.block);
  sel_hits_start := true;
  sel_side := ci.side;
  sel_new := Veci(sel_start);
  sel_hits_new := true;
  case sel_side of
    FRONT:  sel_new.z := sel_start.z + 1;
    BACK:   sel_new.z := sel_start.z - 1;
    TOP:    sel_new.y := sel_start.y + 1;
    BOTTOM: sel_new.y := sel_start.y - 1;
    RIGHT:  sel_new.x := sel_start.x + 1;
    LEFT:   sel_new.x := sel_start.x - 1;
  end;
  sel_hits_new := PointInMap(sel_new);

  //if we are in the new selection block we cant place it!
  sp := VecfTrunc(player.pos);
  if (sp.x = 0) and (player.pos.x < 0) then sp.x := -1;
  if (sp.y = 0) and (player.pos.y < 0) then sp.y := -1;
  if (sp.z = 0) and (player.pos.z < 0) then sp.z := -1;
  if (sel_new.x = sp.x) and (sel_new.y = sp.y) and (sel_new.z = sp.z) then
    sel_hits_new := false;
end;

procedure LeftMouseEdit();
begin
  case editmode of
  EM_GEOMETRY  : if sel_hits_new then CreateBlock(sel_new, sel_tex, BT_SOLID);
  EM_TEXTURING : if sel_hits_start then SetBlockTexture(sel_start, sel_side, sel_tex);
  end;

  sel_hits_new := false;
  sel_hits_start := false;
end;

procedure RightMouseEdit();
begin
  if not(sel_hits_start) then exit;

  case editmode of
  EM_GEOMETRY  : ClearBlock(sel_start);
  EM_TEXTURING : RotateBlockTexture(sel_start, sel_side);
  end;

  sel_hits_new := false;
  sel_hits_start := false;
end;

procedure RenderEditingInterface();
begin
  glBlendFunc(GL_SRC_ALPHA, GL_ONE_MINUS_SRC_ALPHA);
  glEnable(GL_BLEND);
  RenderColorQuad(GL_QUADS,10,10,135,160,0.4,0.4,0.4,0.85);
  glDisable(GL_BLEND);
  RenderColorQuad(GL_LINE_LOOP,10,10,135,160,1,1,1,1);
  RenderColorQuad(GL_LINE_LOOP,10,35,135,0,1,1,1,1);

  glEnable(GL_TEXTURE_2D);
  BindTexture(TT_MAP, sel_tex);
  RenderTexturedQuad(15,40,125,125);
  glDisable(GL_TEXTURE_2D);

  case editmode of
    EM_GEOMETRY  : RenderTextOne('GEOMETRY', 23+15, 15, 0.2);
    EM_TEXTURING : RenderTextOne('TEXTURING', 18+15, 15, 0.2);
  end;
  RenderColorQuad(GL_LINE_LOOP,15,40,125,125,1,1,1,1);
end;

procedure NextTexture();
begin
  sel_tex := sel_tex + 1;
  if sel_tex > length(tex_data[TT_MAP])-1 then
    sel_tex := 0;
end;

procedure PreviousTexture();
begin
  sel_tex := sel_tex - 1;
  if sel_tex < 0 then
    sel_tex := length(tex_data[TT_MAP])-1;
end;

procedure ResetEditing();
begin
  sel_start := Veci(0,0,0);
  sel_new := Veci(0,0,0);
  sel_side := 0; sel_tex := 0;
  sel_hits_new := false; sel_hits_start := false;
end;

end.
