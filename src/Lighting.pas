unit Lighting;

interface

uses
  Math,
  Common,
  Map,
  Frustum,
  Renderer,
  Scripting;

var
  l_mapambient : TColor;
  l_sundiffuse : TColor;
  l_falloff    : TColor;
  l_sundir     : TVecf;

implementation

procedure CalcLighting();
var
  i, x, y, z : integer;
  col : array[1..6] of TColor;
  st  : array[1..6] of Boolean;
  il  : TVecf;
  dot : Single;
  bp  : PBlock;
  sm  : array of array of integer;
  icf : TColor;

  function gpism(const x, y : integer): integer;
  begin
    if ((x < 0) or (y < 0) or (x > map_size-1) or (y > map_size-1)) then begin result := -1; exit; end;
    result := sm[x, y];
  end;
begin
  il := VecfInv(VecfNorm(l_sundir));

  //start calculating lighting
  StartProgress('Calculating lighting...', 3);

  //---------------------------
  // Directional light
  //---------------------------

  //calulate directional light for each cubeside
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
  UpdateProgress(1);

  //apply directional light to all cubes and calculate shadowmaps
  setLength(sm, map_size, map_size);
  for x := 0 to map_size-1 do
  begin
    for z := 0 to map_size-1 do
    begin
      sm[x, z] := -1;
      for y := 0 to map_size-1 do
      begin
        bp := GetBlock(Veci(x, y, z));
        if (bp <> nil) and (bp^.blocktype = BT_SOLID) then
        begin
          for i := 1 to 6 do
          begin
            bp^.col[i] := Color(col[i]);
          end;
          if y > gpism(x, z) then
            sm[x, z] := y;
        end;
      end;
    end;
  end;
  UpdateProgress(1);

  //apply the shadowmap
  for x := 0 to map_size-1 do
  begin
    for z := 0 to map_size-1 do
    begin
      for y := 0 to map_size-1 do
      begin
        bp := GetBlock(Veci(x, y, z));
        if (bp <> nil) and (bp^.blocktype = BT_SOLID) then
        begin
          if y < gpism(x, z) then
            bp^.col[TOP] := l_mapambient
          else
          begin
            if ((y < gpism(x+1, z)) or (y < gpism(x-1, z)) or
                (y < gpism(x, z+1)) or (y < gpism(x, z-1)) or
                (y < gpism(x+1, z+1)) or (y < gpism(x-1, z-1)) or
                (y < gpism(x+1, z-1)) or (y < gpism(x-1, z+1))) then
              bp^.col[TOP] := l_falloff;
          end;

          if ((y < gpism(x+1, z)) and (gpism(x+1, z) <> -1)) then
            bp^.col[RIGHT] := l_mapambient;

          if ((y < gpism(x-1, z)) and (gpism(x-1, z) <> -1)) then
            bp^.col[LEFT] := l_mapambient;

          if ((y < gpism(x, z+1)) and (gpism(x, z+1) <> -1)) then
            bp^.col[FRONT] := l_mapambient;

          if ((y < gpism(x, z-1)) and (gpism(x, z-1) <> -1)) then
            bp^.col[BACK] := l_mapambient;
        end;
      end;
    end;
  end;
  UpdateProgress(1);

  setLength(sm, 0, 0);
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

procedure Falloff(const prms : TParams);
begin
  l_falloff := Color(prms[0].byte, prms[1].byte, prms[2].byte);
end;

procedure SunDir(const prms : TParams);
begin
  l_sundir := Vecf(prms[0].float, prms[1].float, prms[2].float);
end;

initialization
  l_mapambient := Color(100, 100, 100);
  l_sundiffuse := Color(255, 255, 255);
  l_falloff    := Color(200, 200, 200);
  SunDir(Params([P(0.8), P(-1.0), P(-0.5)]));
  RegProc('calcl', @CalcLighting);
  RegProc('mapambient', @MapAmbient, Params([P(T_BYTE), P(T_BYTE), P(T_BYTE)]));
  RegProc('sundiffuse', @SunDiffuse, Params([P(T_BYTE), P(T_BYTE), P(T_BYTE)]));
  RegProc('falloff', @Falloff, Params([P(T_BYTE), P(T_BYTE), P(T_BYTE)]));
  RegProc('sundir', @SunDir, Params([P(T_FLOAT), P(T_FLOAT), P(T_FLOAT)]));
finalization
end.

