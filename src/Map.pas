unit Map;

interface

uses
  Log,
  SysUtils,
  Classes,
  Common,
  Scripting,
  dglOpenGL;

type
  TBlockType = (BT_SOLID, BT_ENTITY);
  TRenderMode = (RM_NORMAL, RM_WIREFRAME, RM_NODEBOUNDS);

  PNode = ^TNode;
  TNode = record
    min, max : TVeci;
    hasdata   : boolean;
    renderdpl : GLuint;
    childs : array of TNode;
  end;

  PBlock = ^TBlock;
  TBlock = packed record
    blocktype : TBlockType;
    tex : array[1..6] of byte;
    uv  : array[1..6] of byte;
    col : array[1..6, 1..4] of TColor;
    p : TVecb;
  end;

procedure CreateBlock(const p : TVeci; const tex : integer; const blocktype : TBlockType; const updatenodes : boolean = true);
procedure ClearBlock(const p : TVeci; const updatenodes : boolean = true);
procedure RotateBlockTexture(const p : TVeci; const side : integer);
procedure SetBlockTexture(const p : TVeci; const side, tex : integer);

function PointInMap(const p : TVeci): boolean;
function GetBlock(const p : TVeci): PBlock;

procedure NewMap(const pars : TParams);
procedure SaveMap(const pars : TParams);
procedure LoadMap(const pars : TParams);
procedure ClearMap(const size : integer);
procedure InitMap();

procedure RenderMap(const rendermode : TRenderMode);

var
  map_size   : integer;
  map_blocks : array of array of array of PBlock;

const
  UV : array[1..6, 1..4, 1..8] of single =
  (
    ((0,0,1,0,1,1,0,1),(1,0,1,1,0,1,0,0),(1,1,0,1,0,0,1,0),(0,1,0,0,1,0,1,1)),
    ((1,0,1,1,0,1,0,0),(1,1,0,1,0,0,1,0),(0,1,0,0,1,0,1,1),(0,0,1,0,1,1,0,1)),
    ((0,1,0,0,1,0,1,1),(0,0,1,0,1,1,0,1),(1,0,1,1,0,1,0,0),(1,1,0,1,0,0,1,0)),
    ((1,1,0,1,0,0,1,0),(0,1,0,0,1,0,1,1),(0,0,1,0,1,1,0,1),(1,0,1,1,0,1,0,0)),
    ((1,0,1,1,0,1,0,0),(1,1,0,1,0,0,1,0),(0,1,0,0,1,0,1,1),(0,0,1,0,1,1,0,1)),
    ((0,0,1,0,1,1,0,1),(1,0,1,1,0,1,0,0),(1,1,0,1,0,0,1,0),(0,1,0,0,1,0,1,1))
  );
  NORM : array[1..6, 1..3] of single =
  (
    ( 0, 0, 1),
    ( 0, 0,-1),
    ( 0, 1, 0),
    ( 0,-1, 0),
    ( 1, 0, 0),
    (-1, 0, 0)
  );
  VERT : array[1..6, 1..4, 1..3] of single =
  (
    ((0,0,1),(1,0,1),(1,1,1),(0,1,1)),
    ((0,0,0),(0,1,0),(1,1,0),(1,0,0)),
    ((0,1,0),(0,1,1),(1,1,1),(1,1,0)),
    ((0,0,0),(1,0,0),(1,0,1),(0,0,1)),
    ((1,0,0),(1,1,0),(1,1,1),(1,0,1)),
    ((0,0,0),(0,0,1),(0,1,1),(0,1,0))
  );

implementation

uses
  Editing,
  Main,
  Renderer,
  Frustum,
  Skybox,
  Lighting,
  Textures;

const
  MAP_VERSION    = '1.0';
  MAP_BASE       = 'maps/';
  MAP_SCRIPT     = 'script.script';
  MAP_DATA       = 'data.bin';

type
  TMapHeader = packed record
    version    : string[5];
    mapsize    : Integer;
    blockcount : Integer;
  end;

var
  map_root : TNode;

function PointInMap(const p : TVeci): boolean;
begin
  result := ((p.x >= 0) and (p.y >= 0) and (p.z >= 0) and (p.x <= map_size-1) and (p.y <= map_size-1) and (p.z <= map_size-1))
end;

function GetBlock(const p : TVeci): PBlock;
begin
  if not(PointInMap(p)) then begin result := nil; exit; end;
  if not(assigned(map_blocks[p.x, p.y, p.z])) then begin result := nil; exit; end;
  result := map_blocks[p.x, p.y, p.z];
end;

procedure InitEndNode(var node : TNode);
type
  TRenderFace = record
    p : TVeci;
    side, rot : byte;
  end;

var
  c : TColor;
  x, y, z, facecount : integer;
  vis_faces : array of array of TRenderFace;

procedure AddSide(const p : TVeci; const side, rot, texture : byte);
var
  i : integer;
begin
  inc(facecount);
  setLength(vis_faces[texture], length(vis_faces[texture])+1);
  i := length(vis_faces[texture])-1;
  vis_faces[texture][i].p := Veci(p);
  vis_faces[texture][i].side := side;
  vis_faces[texture][i].rot := rot;
end;

procedure DetectBlockSides(const p : TVeci; const block : TBlock);
begin
  case block.blocktype of
    BT_SOLID :
    begin
      if p.z < map_size-1 then
      begin
        if not assigned(map_blocks[p.x, p.y, p.z+1]) then
          AddSide(p, FRONT, block.uv[FRONT], block.tex[FRONT]);
      end
      else
        AddSide(p, FRONT, block.uv[FRONT], block.tex[FRONT]);

      if p.z > 0 then
      begin
        if not assigned(map_blocks[p.x, p.y, p.z-1]) then
          AddSide(p, BACK, block.uv[BACK], block.tex[BACK]);
      end
      else
        AddSide(p, BACK, block.uv[BACK], block.tex[BACK]);

      if p.y < map_size-1 then
      begin
        if not assigned(map_blocks[p.x, p.y+1, p.z]) then
          AddSide(p, TOP, block.uv[TOP], block.tex[TOP]);
      end
      else
        AddSide(p, TOP, block.uv[TOP], block.tex[TOP]);

      if p.y > 0 then
      begin
        if not assigned(map_blocks[p.x, p.y-1, p.z]) then
          AddSide(p, BOTTOM, block.uv[BOTTOM], block.tex[BOTTOM]);
      end
      else
        AddSide(p, BOTTOM, block.uv[BOTTOM], block.tex[BOTTOM]);

      if p.x < map_size-1 then
      begin
        if not assigned(map_blocks[p.x+1, y, z]) then
          AddSide(p, RIGHT, block.uv[RIGHT], block.tex[RIGHT]);
      end
      else
        AddSide(p, RIGHT, block.uv[RIGHT], block.tex[RIGHT]);

      if p.x > 0 then
      begin
        if not assigned(map_blocks[x-1, y, z]) then
          AddSide(p, LEFT, block.uv[LEFT], block.tex[LEFT]);
      end
      else
        AddSide(p, LEFT, block.uv[LEFT], block.tex[LEFT]);
    end;
  end;
end;

begin
  //clear the old stuff
  facecount := 0;
  node.hasdata := false;
  glDeleteLists(node.renderdpl, 1);

  //group faces by texture
  setLength(vis_faces, length(tex_data[TT_MAP]));
  for x := node.min.x to node.max.x-1 do
    for y := node.min.y to node.max.y-1 do
      for z := node.min.z to node.max.z-1 do
      begin
        if not assigned(map_blocks[x, y, z]) then continue;
        DetectBlockSides(Veci(x, y, z), map_blocks[x, y, z]^);
      end;

  //no faces then exit
  if facecount = 0 then exit;
  node.hasdata := true;

  //render dpl
  node.renderdpl := glGenLists(1);
  glNewList(node.renderdpl, GL_COMPILE_AND_EXECUTE);
  for x := 0 to length(vis_faces)-1 do
    if length(vis_faces[x]) > 0 then
    begin
      BindTexture(TT_MAP, x);
      glBegin(GL_QUADS);
        for y := 0 to length(vis_faces[x])-1 do
        begin
          with vis_faces[x][y] do
          begin
            //v1
            c := map_blocks[p.x, p.y, p.z]^.col[side][1]; glColor3ub(c.r, c.g, c.b);
            glTexCoord2fv(@UV[side][rot][1]); glVertex3f( VERT[side][1][1]+p.x,  VERT[side][1][2]+p.y,  VERT[side][1][3]+p.z);
            //v2
            c := map_blocks[p.x, p.y, p.z]^.col[side][2]; glColor3ub(c.r, c.g, c.b);
            glTexCoord2fv(@UV[side][rot][3]); glVertex3f( VERT[side][2][1]+p.x,  VERT[side][2][2]+p.y,  VERT[side][2][3]+p.z);
            //v3
            c := map_blocks[p.x, p.y, p.z]^.col[side][3]; glColor3ub(c.r, c.g, c.b);
            glTexCoord2fv(@UV[side][rot][5]); glVertex3f( VERT[side][3][1]+p.x,  VERT[side][3][2]+p.y,  VERT[side][3][3]+p.z);
            //v4
            c := map_blocks[p.x, p.y, p.z]^.col[side][4]; glColor3ub(c.r, c.g, c.b);
            glTexCoord2fv(@UV[side][rot][7]); glVertex3f( VERT[side][4][1]+p.x,  VERT[side][4][2]+p.y,  VERT[side][4][3]+p.z);
          end;
        end;
      glEnd();
    end;
  glEndList();

  setLength(vis_faces, 0);
end;

function GetBlockNode(const p : TVeci): PNode;
var
  endnode : PNode;

procedure CheckNodes(const p : TVeci; const node : PNode);
var
  i : integer;
  n : TNode;
begin
  n := node^;
  If not((n.min.x <= p.X) and (n.min.y <= p.Y) and (n.min.z <= p.Z) and
         (n.max.x >= p.X) and (n.max.y >= p.Y) and (n.max.z >= p.Z)) then
    exit;
  if length(n.childs) = 0 then
    endnode := node
  else
    for i := 0 to length(n.childs)-1 do
      CheckNodes(p, @n.childs[i]);
end;

begin
  CheckNodes(p, @map_root);
  result := endnode;
end;

procedure UpdateBlockNode(const p : TVeci; const adjoining : boolean = false);
var
  n1, n2 : PNode;
begin
  n1 := GetBlockNode(p);
  InitEndNode(n1^);

  if not(adjoining) then exit;

  if p.x+1 < map_size  then
  begin
    n2 := GetBlockNode(p);
    if (n1 <> n2) then
      InitEndNode(n2^);
  end;

  if p.x-1 >= 0  then
  begin
    n2 := GetBlockNode(Veci(p.x-1, p.y, p.z));
    if (n1 <> n2) then
      InitEndNode(n2^);
  end;

  if p.y+1 < map_size  then
  begin
    n2 := GetBlockNode(Veci(p.x, p.y+1, p.z));
    if (n1 <> n2) then
      InitEndNode(n2^);
  end;

  if p.y-1 >= 0  then
  begin
    n2 := GetBlockNode(Veci(p.x, p.y-1, p.z));
    if (n1 <> n2) then
      InitEndNode(n2^);
  end;

  if p.z+1 < map_size  then
  begin
    n2 := GetBlockNode(Veci(p.x, p.y, p.z+1));
    if (n1 <> n2) then
      InitEndNode(n2^);
  end;

  if p.z-1 >= 0  then
  begin
    n2 := GetBlockNode(Veci(p.x, p.y, p.z-1));
    if (n1 <> n2) then
      InitEndNode(n2^);
  end;
end;

procedure InitOctree(var node : TNode);
var
  size, center  : TVeci;
begin
  //calculate the size
  size := VeciDiv(VeciSub(node.max, node.min), Veci(2,2,2));

  //if the size is smaller then 8 don`t go further
  if (size.x < 8) or (size.y < 8) or (size.z < 8) then
  begin
    InitEndNode(node);
    exit;
  end;

  //if we get here init the subnodes.
  center := VeciAdd(node.min, size);
  setLength(node.childs, 8);

  //0
  with node.childs[0] do begin
    min := Veci( node.min);
    max := Veci( center);
  end;
  InitOctree(node.childs[0]);
  //1
  with node.childs[1] do begin
    min := Veci(center.x, node.min.y, node.min.z);
    max := Veci(node.max.x, center.y, center.z);
  end;
  InitOctree(node.childs[1]);
  //2
  with node.childs[2] do begin
    min := Veci(node.min.x, node.min.y, center.z);
    max := Veci(center.x, center.y, node.max.z);
  end;
  InitOctree(node.childs[2]);
  //3
  with node.childs[3] do begin
    min := Veci(center.x, node.min.y, center.z);
    max := Veci(node.max.x, center.y, node.max.z);
  end;
  InitOctree(node.childs[3]);
  //4
  with node.childs[4] do begin
    min := Veci(node.min.x, center.y, node.min.z);
    max := Veci(center.x, node.max.y, center.z);
  end;
  InitOctree(node.childs[4]);
  //5
  with node.childs[5] do begin
    min := Veci(center.x, center.y, node.min.z);
    max := Veci(node.max.x, node.max.y, center.z);
  end;
  InitOctree(node.childs[5]);
  //6
  with node.childs[6] do begin
    min := Veci(node.min.x, center.y, center.z);
    max := Veci(center.x, node.max.y, node.max.z);
  end;
  InitOctree(node.childs[6]);
  //7
  with node.childs[7] do begin
    min := Veci(center);
    max := Veci(node.max);
  end;
  InitOctree(node.childs[7]);
end;

procedure ClearOctree(var node : TNode);
var
  i : integer;
begin
  for i := 0 to length(node.childs)-1 do
    ClearOctree(node.childs[i]);
  glDeleteLists(node.renderdpl, 1);
  setLength(node.childs, 0);
end;

procedure InitMap();
begin
  ClearOctree(map_root);
  map_root.min := Veci(0,0,0);
  map_root.max := Veci(map_size,map_size,map_size);
  InitOctree(map_root);
end;

procedure ResetEditAndPlayer();
var
  mc : integer;
begin
  ResetEditing();
  mc := map_size div 2;
  player.rot := Vecf(0,0,0);
  player.pos := Vecf(mc + 0.01,mc + 1.75, mc + 0.01);
end;

procedure NewMap(const pars : TParams);
var
  x, z, mc : integer;
begin
  //check the size
  if not((pars[0].int = 64) or (pars[0].int = 128) or (pars[0].int = 256)) then
  begin
    Print('Map size needs to be 64, 128 or 256', LT_WARNING);
    exit;
  end;

  //clear old map data
  ClearMap(pars[0].int);

  //add some dummy blocks to stand on
  mc := map_size div 2;
  for x := mc - 2 to mc+1 do
    for z := mc - 2 to mc+1 do
      CreateBlock(Veci(x, mc, z), 0, BT_SOLID, false);

  //init the map
  InitMap();

  //reset the editing and player
  ResetEditAndPlayer();
end;

procedure LoadMap(const pars : TParams);
var
  dir       : String;
  data      : TMemoryStream;
  header    : TMapHeader;
  i         : integer;
  blocks    : array of TBlock;
begin
  dir := basedatadir + MAP_BASE + pars[0].str + '/';
  try
    //some checks
    if Not(DirectoryExists(dir)) then
      raise Exception.Create('Map ' + pars[0].str + ' does not exist!' );

    if Not(FileExists(dir + MAP_SCRIPT)) then
      raise Exception.Create('Map script file does not exist!');

    if Not(FileExists(dir + MAP_DATA)) then
      raise Exception.Create('Map data file does not exist!');

    //load the map binary data
    data := TMemoryStream.Create();
    data.LoadFromFile(dir + MAP_DATA);
    data.Read(header, SizeOf(TMapHeader));
    SetLength(blocks, header.blockcount);
    StartProgress('Loading map...', header.blockcount + 20);
    data.Read(blocks[0], SizeOf(TBlock) * header.blockcount);
    ClearMap(header.mapsize);
    for i := 0 to header.blockcount-1 do
    begin
      UpdateProgress(1);
      new(map_blocks[blocks[i].p.x, blocks[i].p.y, blocks[i].p.z]);
      Move(blocks[i], map_blocks[blocks[i].p.x, blocks[i].p.y, blocks[i].p.z]^, SizeOf(TBlock));
    end;
    FreeAndNil(data);

    //execute the map script
    ExecuteScript(Params([P(MAP_BASE + pars[0].str + '/' + MAP_SCRIPT)]));
    UpdateProgress(10);

    //init the map structure.
    InitMap();
    UpdateProgress(10);

    //reset the editing and player
    ResetEditAndPlayer();

    EndProgress();
  except
    on E: Exception do
    begin
        Print('Map error: ' + E.Message, LT_WARNING);
    end;
  end;
end;

procedure SaveMap(const pars : TParams);
var
  dir     : String;
  script  : TStringlist;
  data    : TFileStream;
  header  : TMapHeader;
  x, y, z, bc : integer;
  blocks  : array of TBlock;
begin
  //create directory
  dir := basedatadir + MAP_BASE + pars[0].str + '/';
  ForceDirectories(dir);

  //start loading
  StartProgress('Saving map...', map_size + 10);

  //save map script
  script := TStringlist.Create();
  //lighting
  script.Add('{set general lighting parameters}');
  script.Add('mapambient(' + IntToStr(l_mapambient.r) + ','
                           + IntToStr(l_mapambient.g) + ','
                           + IntToStr(l_mapambient.b) + ');');
  script.Add('sundiffuse(' + IntToStr(l_sundiffuse.r) + ','
                           + IntToStr(l_sundiffuse.g) + ','
                           + IntToStr(l_sundiffuse.b) + ');');
  script.Add('sundir('  + FormatFloat('0.0',l_sundir.x) + ','
                        + FormatFloat('0.0',l_sundir.y) + ','
                        + FormatFloat('0.0',l_sundir.z) + ');');
  script.Add('');
  //sky
  if sky_loaded then
  begin
    script.Add('{load a skybox}');
    script.Add('loadskybox("' + sky_name + '");');
    script.Add('');
  end;
  //textures
  if length(tex_data[TT_MAP]) > 1 then
  begin
    script.Add('{load the textures}');
    for x := 1 to length(tex_data[TT_MAP])-1 do
      script.Add('loadtexture(2,"' + tex_data[TT_MAP][x].path + '");');
    script.Add('');
  end;
  script.SaveToFile(dir + MAP_SCRIPT);
  FreeAndNil(script);
  UpdateProgress(10);

  //save the map binary data
  data := TFileStream.Create(dir + MAP_DATA, fmCreate);
  header.version := MAP_VERSION;
  header.mapsize := map_size;
  for x := 0 to map_size-1 do
  begin
    for y := 0 to map_size-1 do
    begin
      for z := 0 to map_size-1 do
      begin
        if assigned( map_blocks[x,y,z]) then
          if map_blocks[x, y, z]^.blocktype = BT_SOLID then
          begin
            bc := Length(blocks);
            SetLength(blocks, bc+1);
            Move(map_blocks[x, y, z]^, blocks[bc], SizeOf(TBlock));
          end;
      end;
    end;
    UpdateProgress(1);
  end;
  header.blockcount := Length(blocks);
  data.WriteBuffer(header, SizeOf(TMapHeader));
  data.WriteBuffer(blocks[0], sizeof(TBlock)*Length(blocks));
  FreeAndNil(data);
  EndProgress();
end;

procedure RenderMap(const rendermode : TRenderMode);

procedure RenderNodes(const node : TNode; const rendermode : TRenderMode);

procedure RenderNodeBound(const node : TNode);
begin
  with node do
  begin
    glBegin(GL_LINE_LOOP);
      glVertex3f(min.x, min.y, min.z);
      glVertex3f(max.x, min.y, min.z);
      glVertex3f(max.x, min.y, max.z);
      glVertex3f(min.x, min.y, max.z);
    glEnd();
    glBegin(GL_LINE_LOOP);
      glVertex3f(min.x, max.y, min.z);
      glVertex3f(max.x, max.y, min.z);
      glVertex3f(max.x, max.y, max.z);
      glVertex3f(min.x, max.y, max.z);
    glEnd();
    glBegin(GL_LINES);
      glVertex3f(min.x, min.y, min.z);
      glVertex3f(min.x, max.y, min.z);
      glVertex3f(max.x, min.y, min.z);
      glVertex3f(max.x, max.y, min.z);
      glVertex3f(max.x, min.y, max.z);
      glVertex3f(max.x, max.y, max.z);
      glVertex3f(min.x, min.y, max.z);
      glVertex3f(min.x, max.y, max.z);
    glEnd();
  end;
end;

var
  i : integer;
begin
  if not(BoxInView(Vecf(node.min.x, node.min.y, node.min.z),
                   Vecf(node.max.x, node.max.y, node.max.z))) then
    exit;

  if length(node.childs) > 0 then
  begin
    for i := 0 to length(node.childs)-1 do
      RenderNodes(node.childs[i], rendermode)
  end
  else
  begin
    if not(node.hasdata) then exit;
    case rendermode of
    RM_NORMAL, RM_WIREFRAME : glCallList(node.renderdpl);
    end;
  end;

  if rendermode = RM_NODEBOUNDS then RenderNodeBound(node);
end;

begin
  RenderNodes(map_root, rendermode);
end;

procedure CreateBlock(const p : TVeci; const tex : integer; const blocktype : TBlockType; const updatenodes : boolean = true);
var
  i, j : integer;
begin
  if assigned(map_blocks[p.x, p.y, p.z]) then exit;
  new(map_blocks[p.x, p.y, p.z]);
  map_blocks[p.x, p.y, p.z]^.blocktype := blocktype;
  map_blocks[p.x, p.y, p.z]^.p := Vecb(p.x, p.y, p.z);
  for i := 1 to 6 do
  begin
    map_blocks[p.x, p.y, p.z]^.tex[i] := tex;
    map_blocks[p.x, p.y, p.z]^.uv[i]  := 1;
    for j := 1 to 4 do
      map_blocks[p.x, p.y, p.z]^.col[i][j] := Color(255,255,255);
  end;
  if updatenodes then UpdateBlockNode(p, true);
end;

procedure ClearBlock(const p : TVeci; const updatenodes : boolean = true);
begin
  if not assigned(map_blocks[p.x, p.y, p.z]) then exit;
  Dispose(map_blocks[p.x, p.y, p.z]);
  map_blocks[p.x, p.y, p.z] := nil;
  if updatenodes then UpdateBlockNode(p, true);
end;

procedure SetBlockTexture(const p : TVeci; const side, tex : integer);
begin
  if not assigned(map_blocks[p.x, p.y, p.z]) then exit;
  map_blocks[p.x, p.y, p.z]^.tex[side] := tex;
  UpdateBlockNode(p);
end;

procedure RotateBlockTexture(const p : TVeci; const side : integer);
var
  i : integer;
begin
  if not assigned(map_blocks[p.x, p.y, p.z]) then exit;
  i := map_blocks[p.x, p.y, p.z]^.uv[side];
  inc(i);
  if i > 4 then i := 1;
  map_blocks[p.x, p.y, p.z]^.uv[side] := i;
  UpdateBlockNode(p);
end;

procedure ClearMap(const size : integer);
var
  x, y, z : integer;
begin
  ClearTextures(Params([P(TT_MAP)]));
  ClearOctree(map_root);
  for x := 0 to map_size-1 do
    for y := 0 to map_size-1 do
      for z := 0 to map_size-1 do
        ClearBlock(Veci(x, y, z), false);
  map_size := size;
  SetLength(map_blocks, map_size, map_size, map_size);
end;

initialization
  RegProc('newmap', @NewMap, Params([P(T_INT)]));
  RegProc('loadmap', @LoadMap, Params([P(T_STR)]));
  RegProc('savemap', @SaveMap, Params([P(T_STR)]));
finalization
end.
