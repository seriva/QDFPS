unit Common;

interface

uses
  Math;

type
  TVecf = record
    x, y, z: single
  end;

  TVeci = record
    x, y, z: integer;
  end;

  TVecb = record
    x, y, z: byte;
  end;

  TColor = record
    r, g, b: byte;
  end;

function Vecf(const x, y, z : single): TVecf; overload;
function Vecf(const v : TVecf): TVecf; overload;
function VecfAdd(const v1, v2 : TVecf): TVecf;
function VecfSub(const v1, v2 : TVecf): TVecf;
function VecfMul(const v1, v2 : TVecf): TVecf;
function VecfDiv(const v1, v2 : TVecf): TVecf;
function VecfFloor(const v : TVecf): TVeci;
function VecfSign(const v : TVecf): TVeci;
function VecfTrunc(const v : TVecf): TVeci;
function VecfDot(const v1, v2 : TVecf): single;
function VecfLength(const v : TVecf): single;
function VecfNorm(const v : TVecf): TVecf;
function VecfInv(const v : TVecf): TVecf;

function Vecb(const x, y, z : byte): TVecb; overload;
function Vecb(const v : TVecb): TVecb; overload;

function Veci(const x, y, z : integer): TVeci; overload;
function Veci(const v : TVeci): TVeci; overload;
function VeciAdd(const v1, v2 : TVeci): TVeci;
function VeciSub(const v1, v2 : TVeci): TVeci;
function VeciMul(const v1, v2 : TVeci): TVeci;
function VeciDiv(const v1, v2 : TVeci): TVeci;

function Color(const r, g, b : byte): TColor; overload;
function Color(const c : TColor): TColor; overload;

function Clamp(const x, min, max : integer): integer;

implementation

function Vecf(const x, y, z : single): TVecf; overload;
begin
  result.x := x;
  result.y := y;
  result.z := z;
end;

function Vecf(const v : TVecf): TVecf; overload;
begin
  result.x := v.x;
  result.y := v.y;
  result.z := v.z;
end;

function VecfAdd(const v1, v2 : TVecf): TVecf;
begin
  result.x := v1.x + v2.x;
  result.y := v1.y + v2.y;
  result.z := v1.z + v2.z;
end;

function VecfSub(const v1, v2 : TVecf): TVecf;
begin
  result.x := v1.x - v2.x;
  result.y := v1.y - v2.y;
  result.z := v1.z - v2.z;
end;

function VecfMul(const v1, v2 : TVecf): TVecf;
begin
  result.x := v1.x * v2.x;
  result.y := v1.y * v2.y;
  result.z := v1.z * v2.z;
end;

function VecfDiv(const v1, v2 : TVecf): TVecf;
begin
  result.x := v1.x / v2.x;
  result.y := v1.y / v2.y;
  result.z := v1.z / v2.z;
end;

function VecfFloor(const v : TVecf): TVeci;
begin
  result.x := Floor(v.x);
  result.y := Floor(v.y);
  result.z := Floor(v.z);
end;

function VecfSign(const v : TVecf): TVeci;
begin
  result.x := Sign(v.x);
  result.y := Sign(v.y);
  result.z := Sign(v.z);
end;

function VecfTrunc(const v : TVecf): TVeci;
begin
  result.x := trunc(v.x);
  result.y := trunc(v.y);
  result.z := trunc(v.z);
end;

function VecfDot(const v1, v2 : TVecf): single;
begin
  Result := ( (v1.x * v2.x) + (v1.y * v2.y) + (v1.z * v2.z) );
end;

function VecfLength(const v : TVecf): single;
begin
  Result := sqrt((v.x * v.x) + (v.y * v.y) + (v.z * v.z));
end;

function VecfNorm(const v : TVecf): TVecf;
var
  mag, length : Single;
begin
  mag := VecfLength(v);
  if (mag > 0.0) then
  begin
    length := 1.0 / mag;
    result := VecfMul(v, Vecf(length, length, length));
  end
end;

function VecfInv(const v : TVecf): TVecf;
begin
  result.x := -v.x;
  result.y := -v.y;
  result.z := -v.z;
end;


function Vecb(const x, y, z : byte): TVecb; overload;
begin
  result.x := x;
  result.y := y;
  result.z := z;
end;

function Vecb(const v : TVecb): TVecb; overload;
begin
  result.x := v.x;
  result.y := v.y;
  result.z := v.z;
end;


function Veci(const x, y, z : integer): TVeci; overload;
begin
  result.x := x;
  result.y := y;
  result.z := z;
end;

function Veci(const v : TVeci): TVeci; overload;
begin
  result.x := v.x;
  result.y := v.y;
  result.z := v.z;
end;

function VeciAdd(const v1, v2 : TVeci): TVeci;
begin
  result.x := v1.x + v2.x;
  result.y := v1.y + v2.y;
  result.z := v1.z + v2.z;
end;

function VeciSub(const v1, v2 : TVeci): TVeci;
begin
  result.x := v1.x - v2.x;
  result.y := v1.y - v2.y;
  result.z := v1.z - v2.z;
end;

function VeciMul(const v1, v2 : TVeci): TVeci;
begin
  result.x := v1.x * v2.x;
  result.y := v1.y * v2.y;
  result.z := v1.z * v2.z;
end;

function VeciDiv(const v1, v2 : TVeci): TVeci;
begin
  result.x := v1.x div v2.x;
  result.y := v1.y div v2.y;
  result.z := v1.z div v2.z;
end;


function Color(const r, g, b : byte): TColor;  overload;
begin
  result.r := r;
  result.g := g;
  result.b := b;
end;

function Color(const c : TColor): TColor; overload;
begin
  result.r := c.r;
  result.g := c.g;
  result.b := c.b;
end;

function Clamp(const x, min, max : integer):integer;
begin
  if x > max then
  begin
    result := max;
    exit;
  end;
  if x < min then
  begin
    result := min;
    exit;
  end;
  result := x;
end;

end.

