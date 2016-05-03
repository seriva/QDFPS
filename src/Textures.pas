unit Textures;

interface

uses
  Windows,
  SysUtils,
  Log,
  Scripting,
  dglOpenGL;

type
  TDDColorKey = packed record
    dwColorSpaceLowValue: DWORD;
    dwColorSpaceHighValue: DWORD;
  end;

  TDDPixelFormat = packed record
    dwSize: DWORD;
    dwFlags: DWORD;
    dwFourCC: DWORD;
    case Integer of
      1: (
          dwRGBBitCount : DWORD;
          dwRBitMask : DWORD;
          dwGBitMask : DWORD;
          dwBBitMask : DWORD;
          dwRGBAlphaBitMask : DWORD;
          );
      2: (
          dwYUVBitCount : DWORD;
          dwYBitMask : DWORD;
          dwUBitMask : DWORD;
          dwVBitMask : DWORD;
          dwYUVAlphaBitMask : DWORD;
          );
      3: (
          dwZBufferBitDepth : DWORD;
          dwStencilBitDepth : DWORD;
          dwZBitMask : DWORD;
          dwStencilBitMask : DWORD;
          dwLuminanceAlphaBitMask : DWORD;
          );
      4: (
          dwAlphaBitDepth : DWORD;
          dwLuminanceBitMask : DWORD;
          dwBumpDvBitMask : DWORD;
          dwBumpLuminanceBitMask : DWORD;
          dwRGBZBitMask : DWORD;
          );
      5: (
           dwLuminanceBitCount : DWORD;
           dwBumpDuBitMask : DWORD;
           Fill1, Fill2    : DWORD;
           dwYUVZBitMask   : DWORD;
         );
      6: ( dwBumpBitCount  : DWORD;
         );
  end;

  TDDSCaps2 = packed record
    dwCaps: DWORD;
    dwCaps2 : DWORD;
    dwCaps3 : DWORD;
    dwCaps4 : DWORD;
  end;

  TDDSurfaceDesc2 = packed record
    dwSize: DWORD;
    dwFlags: DWORD;
    dwHeight: DWORD;
    dwWidth: DWORD;
    case Integer of
    0: (
      lPitch : Longint;
     );
    1: (
      dwLinearSize : DWORD;
      dwBackBufferCount: DWORD;
      case Integer of
      0: (
        dwMipMapCount: DWORD;
        dwAlphaBitDepth: DWORD;
        dwReserved: DWORD;
        lpSurface: Pointer;
        ddckCKDestOverlay: TDDColorKey;
        ddckCKDestBlt: TDDColorKey;
        ddckCKSrcOverlay: TDDColorKey;
        ddckCKSrcBlt: TDDColorKey;
        ddpfPixelFormat: TDDPixelFormat;
        ddsCaps: TDDSCaps2;
        dwTextureStage: DWORD;
       );
      1: (
        dwRefreshRate: DWORD;
       );
     );
  end;

  TDDSData = record
    OutputFormat  : Word;
    Factor        : Integer;
    Width         : Integer;
    Height        : Integer;
    NumMipMaps    : Integer;
    Components    : Integer;
    Data          : array of Byte;
  end;

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

  FOURCC_DXT1 = DWORD(Byte('D') or (Byte('X') shl 8) or (Byte('T') shl 16) or (Byte('1') shl 24));
  FOURCC_DXT3 = DWORD(Byte('D') or (Byte('X') shl 8) or (Byte('T') shl 16) or (Byte('3') shl 24));
  FOURCC_DXT5 = DWORD(Byte('D') or (Byte('X') shl 8) or (Byte('T') shl 16) or (Byte('5') shl 24));

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
  path : String;
  iDDSD          : TDDSurfaceDesc2;
  iFileCode      : array[0..3] of AnsiChar;
  iBufferSize    : integer;
  iReadBufferSize: integer;
  iPFile         : THandle;
  iReadBytes     : Longword;
  iDDSData       : TDDSData;
  iBlockSize     : Integer;
  iHeight        : Integer;
  iWidth         : Integer;
  iOffset        : Integer;
  iSize          : Integer;
  iI             : Integer;
  texid          : Integer;

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

     //load the texture
    iPFile := CreateFile(PChar(AnsiString(path)), GENERIC_READ, FILE_SHARE_READ, nil, OPEN_EXISTING, 0, 0);
    if (iPFile = INVALID_HANDLE_VALUE) then
      Raise Exception.Create('Failed to load texture ' + path);

    //verify if it is a true DDS file
    ReadFile( iPFile, iFileCode, 4, iReadBytes, nil);
    if (iFileCode[0] + iFileCode[1] + iFileCode[2] <> 'DDS') then
      Raise Exception.Create('File ' + path + ' is not a valid DDS file.');

    //read surface descriptor
    ReadFile( iPFile, iDDSD, sizeof(iDDSD), iReadBytes, nil );
    case iDDSD.ddpfPixelFormat.dwFourCC of
    FOURCC_DXT1 : begin
                    //DXT1's compression ratio is 8:1
                    iDDSData.OutputFormat := GL_COMPRESSED_RGBA_S3TC_DXT1_EXT;
                    iDDSData.Factor := 2;
                  end;
    FOURCC_DXT3 : begin
                    //DXT3's compression ratio is 4:1
                    iDDSData.OutputFormat := GL_COMPRESSED_RGBA_S3TC_DXT3_EXT;
                    iDDSData.Factor := 4;
                  end;
    FOURCC_DXT5 : begin
                    //DXT5's compression ratio is 4:1
                    iDDSData.OutputFormat := GL_COMPRESSED_RGBA_S3TC_DXT5_EXT;
                    iDDSData.Factor := 4;
                  end;
    else          begin
                    //Not compressed. Oh shit, didn't implement that!
                    Raise Exception.Create('File ' + path + ' has no compression! Loading non-compressed not implemented.');
                  end;
    end;

    //how big will the buffer need to be to load all of the pixel data including mip-maps?
    if( iDDSD.dwLinearSize = 0 ) then
      Raise Exception.Create('File ' + path + ' dwLinearSize is 0.');

    //set the buffer size
    if( iDDSD.dwMipMapCount > 1 ) then
      iBufferSize := iDDSD.dwLinearSize * iDDSData.Factor
    else
      iBufferSize := iDDSD.dwLinearSize;

    //read the buffer data
    iReadBufferSize := iBufferSize * sizeof(Byte);
    setLength(iDDSData.Data, iReadBufferSize);
    if Not(ReadFile( iPFile, iDDSData.Data[0] , iReadBufferSize, iReadBytes, nil)) then
      Raise Exception.Create('Failed to read image data from file ' + path);
    CloseHandle(iPFile);

    //more output info }
    iDDSData.Width      := iDDSD.dwWidth;
    iDDSData.Height     := iDDSD.dwHeight;
    iDDSData.NumMipMaps := iDDSD.dwMipMapCount;

    //do we have a fourth Alpha channel doc?
    if( iDDSD.ddpfPixelFormat.dwFourCC = FOURCC_DXT1 ) then
      iDDSData.Components := 3
    else
      iDDSData.Components := 4;

    glGenTextures(1, @tex_data[params[0].int][texid].tex);
    glBindTexture(GL_TEXTURE_2D, tex_data[params[0].int][texid].tex  );
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_LINEAR);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_LINEAR_MIPMAP_LINEAR);

    if iDDSData.OutputFormat = GL_COMPRESSED_RGBA_S3TC_DXT1_EXT then
      iBlockSize := 8
    else
      iBlockSize := 16;

    iHeight     := iDDSData.height;
    iWidth      := iDDSData.width;
    iOffset     := 0;

    for iI := 0 to iDDSData.NumMipMaps-1 do
    begin
      if iWidth  = 0 then iWidth  := 1;
      if iHeight = 0 then iHeight := 1;

      iSize := ((iWidth+3) div 4) * ((iHeight+3) div 4) * iBlockSize;

      glCompressedTexImage2DARB( GL_TEXTURE_2D,
                                 iI,
                                 iDDSData.Outputformat,
                                 iWidth,
                                 iHeight,
                                 0,
                                 iSize,
                                 pointer( integer(iDDSData.data) + iOffset));
      iOffset := iOffset  + iSize;
      iWidth  := (iWidth  div 2);
      iHeight := (iHeight div 2);
    end;
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

    glGenTextures(1, @tex_data[textype][texid].tex);
    glBindTexture(GL_TEXTURE_2D, tex_data[textype][texid].tex  );
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_LINEAR);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_LINEAR_MIPMAP_LINEAR);
    gluBuild2DMipmaps(GL_TEXTURE_2D, GL_RGBA, 32, 32, GL_RGBA, GL_UNSIGNED_BYTE, @data);
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
