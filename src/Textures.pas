unit Textures;

interface

uses
  SysUtils,
  Log,
  Scripting,
  dglOpenGL;

type
  TTexture = record
    path : String;
    tex  : GLuint;
  end;

const
  TT_GLOBAL = 0;
  TT_SKYBOX = 1;
  TT_MAP    = 2;
  TT_MODEL  = 3;
  TEX_TYPEMAX = 256;

var
  tex_data : array[0..3] of array of TTexture;

procedure SetWrapMode(const mode : integer);
procedure BindTexture(const textype, texid : integer);
procedure LoadTexture(const params : TParams);
procedure ClearTextures(const params : TParams);
procedure ClearAllTextures();

implementation

uses
  Main;

procedure SetWrapMode(const mode : integer);
begin
  glTexParameterf( GL_TEXTURE_2D, GL_TEXTURE_WRAP_S, mode );
  glTexParameterf( GL_TEXTURE_2D, GL_TEXTURE_WRAP_T, mode );
end;

procedure CreateTexture(const width, height, channels, textype, texid : integer; const data : pointer);
begin
  glGenTextures(1, @tex_data[textype][texid].tex);
  glBindTexture(GL_TEXTURE_2D, tex_data[textype][texid].tex  );
  glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_LINEAR);
  glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_LINEAR_MIPMAP_LINEAR);
  if channels = 4 then
    gluBuild2DMipmaps(GL_TEXTURE_2D, GL_RGBA, Width, Height, GL_RGBA, GL_UNSIGNED_BYTE, data)
  else
    gluBuild2DMipmaps(GL_TEXTURE_2D, GL_RGB, Width, Height, GL_RGB, GL_UNSIGNED_BYTE, data);
end;

procedure LoadTexture(const params : TParams);
var
  TGAHeader : packed record
    FileType     : Byte;
    ColorMapType : Byte;
    ImageType    : Byte;
    ColorMapSpec : Array[0..4] of Byte;
    OrigX  : Array [0..1] of Byte;
    OrigY  : Array [0..1] of Byte;
    Width  : Array [0..1] of Byte;
    Height : Array [0..1] of Byte;
    BPP    : Byte;
    ImageInfo : Byte;
  end;
  path : String;
  tgafile : File;
  bytesread : Integer;
  width, height, colordepth, channels, imgsize, i, texid : Integer;
  image : array of byte;
  temp : Byte;
begin
  path :=  basedatadir + params[1].str;
  try
    if ((params[0].int < 0) or (params[0].int > length(tex_data)-1)) then
      raise Exception.Create('Texture type index out of bound');

    if Not(FileExists(path)) then
      raise Exception.Create('Texture ' + params[1].str + ' does not exist!' );

    texid := Length(tex_data[params[0].int]);
    if texid > TEX_TYPEMAX then
       raise Exception.Create('Texture count for type ' + IntToStr(params[0].int) + 'reached');
    SetLength(tex_data[params[0].int], texid+1);
    tex_data[params[0].int][texid].path := params[1].str;

    //GetMem(image, 0);
    AssignFile(tgafile, path);
    Reset(tgafile, 1);
    BlockRead(tgafile, TGAHeader, SizeOf(TGAHeader));

    //only support uncompressed images
    if (TGAHeader.ImageType <> 2) then
      raise Exception.Create('Failed to load ' + params[1].str + '! Compressed TGA files not supported.');

    //don't support colormapped files
    if TGAHeader.ColorMapType <> 0 then
      raise Exception.Create('Failed to load ' + params[1].str + '! Colormapped TGA files not supported.');

    //get the width, height, channels and colordepth
    width  := TGAHeader.Width[0]  + TGAHeader.Width[1]  * 256;
    height := TGAHeader.Height[0] + TGAHeader.Height[1] * 256;
    colordepth := TGAHeader.BPP;
    channels := colordepth div 8;
    imgsize  := width*height*channels;

    //don't support lower 3 channels
    if channels < 3 then
      raise Exception.Create('Failed to load ' + params[1].str + '! Only 24 and 32 bit TGA files supported.');

    //load the image data
    setlength(image, imgsize);
    BlockRead(tgafile, image[0], imgsize, bytesread);
    if bytesread <> imgsize then
      raise Exception.Create('Failed to load ' + params[1].str + '! Error while reading image data.');

    //swap BGR(A) to RGB(A)
    for I :=0 to Width * Height - 1 do
    begin
      temp := image[I*channels] ;
      image[I*channels] := image[(I*channels) + 2];
      image[(I*channels) + 2] := temp;
    end;

    //load the actual texture in opengl
    CreateTexture(width, height, channels, params[0].int, texid, @image[0]);

    SetWrapMode(GL_REPEAT);
    CloseFile(tgaFile);
    setlength(Image, 0);
  except
    on E: Exception do
    begin
      Print('Texture error: ' + E.Message, LT_WARNING);
    end;
  end;
end;

procedure CreateDummyTexture(const textype : integer);
const
  B = 0;
  W = MaxInt;
var
  texid : integer;
  data  : array[0..1023] of Integer =
    (B, B, B, B, B, B, B, B, B, B, B, B, B, B, B, B, W, W, W, W, W, W, W, W, W, W, W, W, W, W, W, W,
     B, B, B, B, B, B, B, B, B, B, B, B, B, B, B, B, W, W, W, W, W, W, W, W, W, W, W, W, W, W, W, W,
     B, B, B, B, B, B, B, B, B, B, B, B, B, B, B, B, W, W, W, W, W, W, W, W, W, W, W, W, W, W, W, W,
     B, B, B, B, B, B, B, B, B, B, B, B, B, B, B, B, W, W, W, W, W, W, W, W, W, W, W, W, W, W, W, W,
     B, B, B, B, B, B, B, B, B, B, B, B, B, B, B, B, W, W, W, W, W, W, W, W, W, W, W, W, W, W, W, W,
     B, B, B, B, B, B, B, B, B, B, B, B, B, B, B, B, W, W, W, W, W, W, W, W, W, W, W, W, W, W, W, W,
     B, B, B, B, B, B, B, B, B, B, B, B, B, B, B, B, W, W, W, W, W, W, W, W, W, W, W, W, W, W, W, W,
     B, B, B, B, B, B, B, B, B, B, B, B, B, B, B, B, W, W, W, W, W, W, W, W, W, W, W, W, W, W, W, W,
     B, B, B, B, B, B, B, B, B, B, B, B, B, B, B, B, W, W, W, W, W, W, W, W, W, W, W, W, W, W, W, W,
     B, B, B, B, B, B, B, B, B, B, B, B, B, B, B, B, W, W, W, W, W, W, W, W, W, W, W, W, W, W, W, W,
     B, B, B, B, B, B, B, B, B, B, B, B, B, B, B, B, W, W, W, W, W, W, W, W, W, W, W, W, W, W, W, W,
     B, B, B, B, B, B, B, B, B, B, B, B, B, B, B, B, W, W, W, W, W, W, W, W, W, W, W, W, W, W, W, W,
     B, B, B, B, B, B, B, B, B, B, B, B, B, B, B, B, W, W, W, W, W, W, W, W, W, W, W, W, W, W, W, W,
     B, B, B, B, B, B, B, B, B, B, B, B, B, B, B, B, W, W, W, W, W, W, W, W, W, W, W, W, W, W, W, W,
     B, B, B, B, B, B, B, B, B, B, B, B, B, B, B, B, W, W, W, W, W, W, W, W, W, W, W, W, W, W, W, W,
     B, B, B, B, B, B, B, B, B, B, B, B, B, B, B, B, W, W, W, W, W, W, W, W, W, W, W, W, W, W, W, W,
     W, W, W, W, W, W, W, W, W, W, W, W, W, W, W, W, B, B, B, B, B, B, B, B, B, B, B, B, B, B, B, B,
     W, W, W, W, W, W, W, W, W, W, W, W, W, W, W, W, B, B, B, B, B, B, B, B, B, B, B, B, B, B, B, B,
     W, W, W, W, W, W, W, W, W, W, W, W, W, W, W, W, B, B, B, B, B, B, B, B, B, B, B, B, B, B, B, B,
     W, W, W, W, W, W, W, W, W, W, W, W, W, W, W, W, B, B, B, B, B, B, B, B, B, B, B, B, B, B, B, B,
     W, W, W, W, W, W, W, W, W, W, W, W, W, W, W, W, B, B, B, B, B, B, B, B, B, B, B, B, B, B, B, B,
     W, W, W, W, W, W, W, W, W, W, W, W, W, W, W, W, B, B, B, B, B, B, B, B, B, B, B, B, B, B, B, B,
     W, W, W, W, W, W, W, W, W, W, W, W, W, W, W, W, B, B, B, B, B, B, B, B, B, B, B, B, B, B, B, B,
     W, W, W, W, W, W, W, W, W, W, W, W, W, W, W, W, B, B, B, B, B, B, B, B, B, B, B, B, B, B, B, B,
     W, W, W, W, W, W, W, W, W, W, W, W, W, W, W, W, B, B, B, B, B, B, B, B, B, B, B, B, B, B, B, B,
     W, W, W, W, W, W, W, W, W, W, W, W, W, W, W, W, B, B, B, B, B, B, B, B, B, B, B, B, B, B, B, B,
     W, W, W, W, W, W, W, W, W, W, W, W, W, W, W, W, B, B, B, B, B, B, B, B, B, B, B, B, B, B, B, B,
     W, W, W, W, W, W, W, W, W, W, W, W, W, W, W, W, B, B, B, B, B, B, B, B, B, B, B, B, B, B, B, B,
     W, W, W, W, W, W, W, W, W, W, W, W, W, W, W, W, B, B, B, B, B, B, B, B, B, B, B, B, B, B, B, B,
     W, W, W, W, W, W, W, W, W, W, W, W, W, W, W, W, B, B, B, B, B, B, B, B, B, B, B, B, B, B, B, B,
     W, W, W, W, W, W, W, W, W, W, W, W, W, W, W, W, B, B, B, B, B, B, B, B, B, B, B, B, B, B, B, B,
     W, W, W, W, W, W, W, W, W, W, W, W, W, W, W, W, B, B, B, B, B, B, B, B, B, B, B, B, B, B, B, B);
begin
    if ((textype < 0) or (textype > length(tex_data)-1)) then
      raise Exception.Create('Texture type index out of bound');

    texid := Length(tex_data[textype]);
    if texid > TEX_TYPEMAX then
       raise Exception.Create('Texture count for type ' + IntToStr(texid) + 'reached');
    SetLength(tex_data[textype], texid+1);
    tex_data[textype][texid].path := '';

    CreateTexture(32, 32, 4, textype, texid, @data);
    SetWrapMode(GL_REPEAT);
end;

procedure BindTexture(const textype, texid : integer);
begin
  if ((textype < 0) or (textype > length(tex_data)-1)) then
  begin
    Print('Texture type index out of bound', LT_WARNING);
    exit;
  end;
  if ((texid < 0) or (texid > length(tex_data[textype])-1)) then
  begin
    Print('Texture index out of bound', LT_WARNING);
    exit;
  end;
  glBindTexture(GL_TEXTURE_2D, tex_data[textype][texid].tex);
end;

procedure ClearTextures(const params : TParams);
var
  i : integer;
begin
  if ((params[0].int < 0) or (params[0].int > length(tex_data)-1)) then
  begin
    Print('Texture type index out of bound', LT_WARNING);
    exit;
  end;
  for i := 0 to length(tex_data[params[0].int])-1 do
  begin
    glDeleteTextures(1, @tex_data[params[0].int][i].tex);
    tex_data[params[0].int][i].path := '';
    tex_data[params[0].int][i].tex  := 0;
  end;
  SetLength(tex_data[params[0].int], 0);

  //add dummy to map textures.
  if params[0].int = TT_MAP then
    CreateDummyTexture(TT_MAP);
end;

procedure ClearAllTextures();
var
  i : Integer;
begin
  for i := 0 to length(tex_data)-1 do
    ClearTextures(Params([P(i)]))
end;

initialization
  RegProc('loadtexture', @LoadTexture, Params([P(T_INT), P(T_STR)]));
finalization
end.
