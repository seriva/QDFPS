unit Physics;

interface

uses
  Common,
  SysUtils;

type
  TCollisionInfo = record
    collided : boolean;
    block : TVeci;
    side : integer;
    pos : TVecf;
    distance : single;
  end;

function RayCast(const pos : TVecf; const dir : TVecf; const radius : single): TCollisionInfo;
function SphereLevelCollision(var v  : TVecf; const radius : Single): boolean;

implementation

uses
  Frustum,
  Math,
  Main,
  Map;

function SphereLevelCollision(var v  : TVecf; const radius : Single): boolean;
var
  sx, sy, sz : integer;
  epx, enx, epy, eny, epz, enz : integer;
  dx, dy, dz : single;
  collision : boolean;

function MapCheck(const x,y,z : integer): boolean;
var
  bp : Pblock;
begin
  result := false;
  bp := GetBlock(Veci(x, y, z));
  if (bp <> nil) and (bp^.blocktype = BT_SOLID) then
  begin
    collision := true;
    result := true;
  end;
end;

begin
  collision := false;
  sx := trunc(v.x); if (sx = 0) and (v.x < 0) then sx := -1;
  sy := trunc(v.y); if (sy = 0) and (v.y < 0) then sy := -1;
  sz := trunc(v.z); if (sz = 0) and (v.z < 0) then sz := -1;
  epx := trunc(v.x + radius); if (epx = 0) and ((v.x + radius) < 0) then epx := -1;
  enx := trunc(v.x - radius); if (enx = 0) and ((v.x - radius) < 0) then enx := -1;
  epy := trunc(v.y + radius); if (epy = 0) and ((v.y + radius) < 0) then epy := -1;
  eny := trunc(v.y - radius); if (eny = 0) and ((v.y - radius) < 0) then eny := -1;
  epz := trunc(v.z + radius); if (epz = 0) and ((v.z + radius) < 0) then epz := -1;
  enz := trunc(v.z - radius); if (enz = 0) and ((v.z - radius) < 0) then enz := -1;

  //sides
  if MapCheck(epx, sy, sz) then v.x := v.x - ((v.x + radius) - epx);
  if MapCheck(enx, sy, sz) then v.x := v.x + ((enx+1) - (v.x - radius));
  if MapCheck(sx, sy, epz) then v.z := v.z - ((v.z + radius) - epz);
  if MapCheck(sx, sy, enz) then v.z := v.z + ((enz+1) - (v.z - radius));
  if MapCheck(sx, epy, sz) then v.y := v.y - ((v.y + radius) - epy);
  if MapCheck(sx, eny, sz) then v.y := v.y + ((eny+1) - (v.y - radius));

  //edges
  if MapCheck(epx, sy, epz) then
  begin
    dx := ((v.x + radius) - epx);
    dz := ((v.z + radius) - epz);
    if dx < dz then
      v.x := v.x - dx
    else
      v.z := v.z - dz;
  end;

  if MapCheck(enx, sy, enz) then
  begin
    dx := ((enx+1) - (v.x - radius));
    dz := ((enz+1) - (v.z - radius));
    if dx < dz then
      v.x := v.x + dx
    else
      v.z := v.z + dz;
  end;

  if MapCheck(epx, sy, enz) then
  begin
    dx := ((v.x + radius) - epx);
    dz := ((enz+1) - (v.z - radius));
    if dx < dz then
      v.x := v.x - dx
    else
      v.z := v.z + dz;
  end;

  if MapCheck(enx, sy, epz) then
  begin
    dx := ((enx+1) - (v.x - radius));
    dz := ((v.z + radius) - epz);
    if dx < dz then
      v.x := v.x + dx
    else
      v.z := v.z - dz;
  end;






  if MapCheck(epx, epy, sz) then
  begin
    dx := ((v.x + radius) - epx);
    dy := ((v.y + radius) - epy);
    if dx < dy then
      v.x := v.x - dx
    else
      v.y := v.y - dy;
  end;

  if MapCheck(enx, eny, sz) then
  begin
    dx := ((enx+1) - (v.x - radius));
    dy := ((eny+1) - (v.y - radius));
    if dx < dy then
      v.x := v.x + dx
    else
      v.y := v.y + dy;
  end;

  if MapCheck(epx, eny, sz) then
  begin
    dx := ((v.x + radius) - epx);
    dy := ((eny+1) - (v.y - radius));
    if dx < dy then
      v.x := v.x - dx
    else
      v.y := v.y + dy;
  end;

  if MapCheck(enx, epy, sz) then
  begin
    dx := ((enx+1) - (v.x - radius));
    dy := ((v.y + radius) - epy);
    if dx < dy then
      v.x := v.x + dx
    else
      v.y := v.y - dy;
  end;





  if MapCheck(sx, epy, epz) then
  begin
    dz := ((v.z + radius) - epz);
    dy := ((v.y + radius) - epy);
    if dz < dy then
      v.z := v.z - dz
    else
      v.y := v.y - dy;
  end;

  if MapCheck(sx, eny, enz) then
  begin
    dz := ((enz+1) - (v.z - radius));
    dy := ((eny+1) - (v.y - radius));
    if dz < dy then
      v.z := v.z + dz
    else
      v.y := v.y + dy;
  end;

  if MapCheck(sx, eny, epz) then
  begin
    dz := ((v.z + radius) - epz);
    dy := ((eny+1) - (v.y - radius));
    if dz < dy then
      v.z := v.z - dz
    else
      v.y := v.y + dy;
  end;

  if MapCheck(sx, epy, enz) then
  begin
    dz := ((enz+1) - (v.z - radius));
    dy := ((v.y + radius) - epy);
    if dz < dy then
      v.z := v.z + dz
    else
      v.y := v.y - dy;
  end;

  result := collision;
end;

function  RayCast(const pos : TVecf; const dir : TVecf; const radius : single): TCollisionInfo;
var
  p, po, step : TVeci;
  d, max, delta : TVecf;
  r : single;

function mod1(const n,d: single): single;
var
  i: integer;
begin
  i := trunc(n / d);
  result := n - d * i;
end;

function mod2(const value, modulus : single) : single;
begin
  result := mod1((mod1(value, modulus) + modulus), modulus);
end;

function intbound(const s, ds : single): single;
var
  sv : single;
begin
  sv := s;
  if (ds < 0) then
    result := intbound(-sv, -ds)
  else
  begin
    sv := mod2(sv, 1);
    result := (1-sv)/ds;
  end;
end;

function check(): boolean;
var
  bx, by, bz : boolean;
begin
  if step.x >= 0 then bx := (p.x < map_size) else bx := (p.x >= 0);
  if step.y >= 0 then by := (p.y < map_size) else by := (p.y >= 0);
  if step.z >= 0 then bz := (p.z < map_size) else bz := (p.z >= 0);
  result := bx and by and bz
end;

begin
  result.collided := false;

  p := VecfFloor(pos);
  po := Veci(p);
  step := VecfSign(dir);
  d := Vecf(dir);

  if not(d.x <> 0) then d.x := 0.0000001;
  if not(d.y <> 0) then d.y := 0.0000001;
  if not(d.z <> 0) then d.z := 0.0000001;

  max.x := intbound(pos.x, d.x);
  max.y := intbound(pos.y, d.y);
  max.z := intbound(pos.z, d.z);

  delta := VecfDiv(Vecf(step.x, step.y, step.z), d);

  r := radius / sqrt(d.x*d.x + d.y*d.y + d.z*d.z);
  while check() do
  begin
    if not((p.x = po.x) and (p.y = po.y) and (p.z = po.z)) then
    begin
      if GetBlock(p) <> nil then
      begin
        result.collided := true;
        result.block := Veci(p);
        break;
      end;
    end;

    if (max.x < max.y) then
    begin
      if (max.x < max.z) then
      begin
        if (max.x > r) then break;
        p.x   := p.x + step.x;
        max.x := max.x + delta.x;
        if step.x < 0 then
          result.side := RIGHT
        else
          result.side := LEFT;
      end
      else
      begin
        if (max.z > r) then break;
        p.z := p.z + step.z;
        max.z := max.z + delta.z;
        if step.z < 0 then
          result.side := FRONT
        else
          result.side := BACK;
      end
    end
    else
    begin
      if (max.y < max.z) then
      begin
        if (max.y > r) then break;
        p.y   := p.y + step.y;
        max.y := max.y + delta.y;
        if step.y < 0 then
          result.side := TOP
        else
          result.side := BOTTOM;
      end
      else
      begin
        if (max.z > r) then break;
        p.z   := p.z + step.z;
        max.z := max.z + delta.z;
        if step.z < 0 then
          result.side := FRONT
        else
          result.side := BACK;
      end;
    end;
  end;
end;

end.
