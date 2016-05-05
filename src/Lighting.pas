unit Lighting;

interface

uses
  Math,
  Common,
  Map,
  Physics,
  Renderer,
  Scripting;

var
  l_mapambient : TColor;
  l_sundiffuse : TColor;
  l_sundir     : TVecf;

implementation

procedure CalcLighting();
var
  i, j, x, y, z : integer;
  col : array[1..6] of TColor;
  st  : array[1..6] of Boolean;
  il, p  : TVecf;
  dot : Single;
  bp  : PBlock;
  ci  : TCollisionInfo;
begin
  il := VecfInv(VecfNorm(l_sundir));

  //start calculating lighting
  StartProgress('Calculating lighting...', (map_size) + 10);

  //preprocess most expensive calculations for a single cube
  for i := 1 to 6 do
  begin
    dot := Max(0, VecfDot(il, Vecf(NORM[i][1], NORM[i][2], NORM[i][3])));
    if (dot > 0) then
    begin
      col[i].r := Clamp(l_mapambient.r + round(l_sundiffuse.r * dot), 0, 255);
      col[i].g := Clamp(l_mapambient.g + round(l_sundiffuse.g * dot), 0, 255);
      col[i].b := Clamp(l_mapambient.b + round(l_sundiffuse.b * dot), 0, 255);
      st[i] := true;
    end
    else
    begin
      col[i] := Color(l_mapambient);
      st[i]  := false;
    end;
  end;
  UpdateProgress(10);

  //now for each cube.
  for x := 0 to map_size-1 do
  begin
    for y := 0 to map_size-1 do
    begin
      for z := 0 to map_size-1 do
      begin
        bp := GetBlock(Veci(x, y, z));
        if (bp <> nil) and (bp^.blocktype = BT_SOLID) then
        begin
          for i := 1 to 6 do
          begin
            for j := 1 to 4 do
              bp^.col[i] := Color(col[i]);
          end;
        end;
      end;
    end;
    UpdateProgress(1);
  end;

  InitMap();
  EndProgress();
end;

procedure MapAmbient(const prms : TParams);
begin
  l_mapambient := Color(prms[0].byte, prms[1].byte, prms[2].byte);
end;

procedure SunDiffuse(const prms : TParams);
begin
  l_sundiffuse := Color(prms[0].byte, prms[1].byte, prms[2].byte);
end;

procedure SunDir(const prms : TParams);
begin
  l_sundir := Vecf(prms[0].float, prms[1].float, prms[2].float);
end;

initialization
  l_mapambient := Color(100, 100, 100);
  l_sundiffuse := Color(255, 255, 255);
  SunDir(Params([P(0.8), P(-1.0), P(-0.5)]));
  RegProc('calclighting', @CalcLighting);
  RegProc('mapambient', @MapAmbient, Params([P(T_BYTE), P(T_BYTE), P(T_BYTE)]));
  RegProc('sundiffuse', @SunDiffuse, Params([P(T_BYTE), P(T_BYTE), P(T_BYTE)]));
  RegProc('sundir', @SunDir, Params([P(T_FLOAT), P(T_FLOAT), P(T_FLOAT)]));
finalization
end.

