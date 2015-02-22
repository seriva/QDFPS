unit Frustum;

interface

uses
  Common,
  dglOpenGL;

procedure CalculateFrustum();
function  PointInView(const p : TVecf) : Boolean;
function  SphereInView(const p : TVecf; const radius : single) : Boolean;
function  BoxInView(const min, max : TVecf) : Boolean;

const
  FRONT  = 1;
  BACK   = 2;
  TOP    = 3;
  BOTTOM = 4;
  RIGHT  = 5;
  LEFT   = 6;

implementation

const
  A = 0;
  B = 1;
  C = 2;
  D = 3;

var
  frustum_planes : array[1..6,0..3] of Single;

procedure NormalizePlane(plane : integer);
var
  magnitude : single;
begin
  magnitude := Sqrt(Sqr(frustum_planes[plane][A])+Sqr(frustum_planes[plane][B])+Sqr(frustum_planes[plane][C]));
  frustum_planes[plane][A] := frustum_planes[plane][A]/magnitude;
  frustum_planes[plane][B] := frustum_planes[plane][B]/magnitude;
  frustum_planes[plane][C] := frustum_planes[plane][C]/magnitude;
  frustum_planes[plane][D] := frustum_planes[plane][D]/magnitude;
end;

procedure CalculateFrustum();
var
  projm, modm, clip : array[0..15] of Single;
begin
  glGetFloatv(GL_PROJECTION_MATRIX, @projm);
  glGetFloatv(GL_MODELVIEW_MATRIX, @modm);

  clip[ 0] := modm[ 0]*projm[ 0] + modm[ 1]*projm[ 4] + modm[ 2]*projm[ 8] + modm[ 3]*projm[12];
  clip[ 1] := modm[ 0]*projm[ 1] + modm[ 1]*projm[ 5] + modm[ 2]*projm[ 9] + modm[ 3]*projm[13];
  clip[ 2] := modm[ 0]*projm[ 2] + modm[ 1]*projm[ 6] + modm[ 2]*projm[10] + modm[ 3]*projm[14];
  clip[ 3] := modm[ 0]*projm[ 3] + modm[ 1]*projm[ 7] + modm[ 2]*projm[11] + modm[ 3]*projm[15];
  clip[ 4] := modm[ 4]*projm[ 0] + modm[ 5]*projm[ 4] + modm[ 6]*projm[ 8] + modm[ 7]*projm[12];
  clip[ 5] := modm[ 4]*projm[ 1] + modm[ 5]*projm[ 5] + modm[ 6]*projm[ 9] + modm[ 7]*projm[13];
  clip[ 6] := modm[ 4]*projm[ 2] + modm[ 5]*projm[ 6] + modm[ 6]*projm[10] + modm[ 7]*projm[14];
  clip[ 7] := modm[ 4]*projm[ 3] + modm[ 5]*projm[ 7] + modm[ 6]*projm[11] + modm[ 7]*projm[15];
  clip[ 8] := modm[ 8]*projm[ 0] + modm[ 9]*projm[ 4] + modm[10]*projm[ 8] + modm[11]*projm[12];
  clip[ 9] := modm[ 8]*projm[ 1] + modm[ 9]*projm[ 5] + modm[10]*projm[ 9] + modm[11]*projm[13];
  clip[10] := modm[ 8]*projm[ 2] + modm[ 9]*projm[ 6] + modm[10]*projm[10] + modm[11]*projm[14];
  clip[11] := modm[ 8]*projm[ 3] + modm[ 9]*projm[ 7] + modm[10]*projm[11] + modm[11]*projm[15];
  clip[12] := modm[12]*projm[ 0] + modm[13]*projm[ 4] + modm[14]*projm[ 8] + modm[15]*projm[12];
  clip[13] := modm[12]*projm[ 1] + modm[13]*projm[ 5] + modm[14]*projm[ 9] + modm[15]*projm[13];
  clip[14] := modm[12]*projm[ 2] + modm[13]*projm[ 6] + modm[14]*projm[10] + modm[15]*projm[14];
  clip[15] := modm[12]*projm[ 3] + modm[13]*projm[ 7] + modm[14]*projm[11] + modm[15]*projm[15];

  frustum_planes[RIGHT][A] := clip[ 3] - clip[ 0];
  frustum_planes[RIGHT][B] := clip[ 7] - clip[ 4];
  frustum_planes[RIGHT][C] := clip[11] - clip[ 8];
  frustum_planes[RIGHT][D] := clip[15] - clip[12];
  NormalizePlane(RIGHT);

  frustum_planes[LEFT][A] := clip[ 3] + clip[ 0];
  frustum_planes[LEFT][B] := clip[ 7] + clip[ 4];
  frustum_planes[LEFT][C] := clip[11] + clip[ 8];
  frustum_planes[Left][D] := clip[15] + clip[12];
  NormalizePlane(LEFT);

  frustum_planes[BOTTOM][A] := clip[ 3] + clip[ 1];
  frustum_planes[BOTTOM][B] := clip[ 7] + clip[ 5];
  frustum_planes[BOTTOM][C] := clip[11] + clip[ 9];
  frustum_planes[BOTTOM][D] := clip[15] + clip[13];
  NormalizePlane(BOTTOM);

  frustum_planes[TOP][A] := clip[ 3] - clip[ 1];
  frustum_planes[TOP][B] := clip[ 7] - clip[ 5];
  frustum_planes[TOP][C] := clip[11] - clip[ 9];
  frustum_planes[TOP][D] := clip[15] - clip[13];
  NormalizePlane(TOP);

  frustum_planes[BACK][A] := clip[ 3] - clip[ 2];
  frustum_planes[BACK][B] := clip[ 7] - clip[ 6];
  frustum_planes[BACK][C] := clip[11] - clip[10];
  frustum_planes[BACK][D] := clip[15] - clip[14];
  NormalizePlane(BACK);

  frustum_planes[FRONT][A] := clip[ 3] + clip[ 2];
  frustum_planes[FRONT][B] := clip[ 7] + clip[ 6];
  frustum_planes[FRONT][C] := clip[11] + clip[10];
  frustum_planes[FRONT][D] := clip[15] + clip[14];
  NormalizePlane(FRONT);
end;

function  PointInView(const p : TVecf) : Boolean;
var
  i : integer;
begin
  result := true;
  for i := 1 to 6 do
  begin
    if (frustum_planes[i][A]*p.x + frustum_planes[i][B]*p.y + frustum_planes[i][C]*p.z + frustum_planes[i][D]) <= 0 then
    begin
      result := false;
      exit;
    end;
  end;
end;

function SphereInView(const p : TVecf; const radius : single) : Boolean;
var
  i : Integer;
begin
  result := true;
  for i := 1 to 6 do
  begin
    if (frustum_planes[i][A]*p.x + frustum_planes[i][B]*p.y + frustum_planes[i][C]*p.z + frustum_planes[i][D]) <= -radius then
    begin
      result := false;
      exit;
    end;
  end;
end;

function BoxInView(const min, max : TVecf) : Boolean;
var
  i : integer;
begin
  result := false;
  for i := 1 to 6 do
  begin
    if frustum_planes[i][A] * min.x + frustum_planes[i][B] * min.y + frustum_planes[i][C] * min.z + frustum_planes[i][D] > 0 then continue;
    if frustum_planes[i][A] * max.x + frustum_planes[i][B] * min.y + frustum_planes[i][C] * min.z + frustum_planes[i][D] > 0 then continue;
    if frustum_planes[i][A] * min.x + frustum_planes[i][B] * max.y + frustum_planes[i][C] * min.z + frustum_planes[i][D] > 0 then continue;
    if frustum_planes[i][A] * max.x + frustum_planes[i][B] * max.y + frustum_planes[i][C] * min.z + frustum_planes[i][D] > 0 then continue;
    if frustum_planes[i][A] * min.x + frustum_planes[i][B] * min.y + frustum_planes[i][C] * max.z + frustum_planes[i][D] > 0 then continue;
    if frustum_planes[i][A] * max.x + frustum_planes[i][B] * min.y + frustum_planes[i][C] * max.z + frustum_planes[i][D] > 0 then continue;
    if frustum_planes[i][A] * min.x + frustum_planes[i][B] * max.y + frustum_planes[i][C] * max.z + frustum_planes[i][D] > 0 then continue;
    if frustum_planes[i][A] * max.x + frustum_planes[i][B] * max.y + frustum_planes[i][C] * max.z + frustum_planes[i][D] > 0 then continue;
    exit;
  end;
  result := true
end;

end.
