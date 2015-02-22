unit Scripting;

interface

uses
  SysUtils, Classes;

type
  TComType   = (CT_VAR, CT_PROC, CT_PROCPARAM);
  TType      = (T_BOOL, T_INT, T_FLOAT, T_STR, T_BYTE);

  PBoolean  = ^Boolean;
  PInteger  = ^Integer;
  PFloat    = ^Single;
  PStr      = ^String;
  PByte     = ^byte;
  TVar = record
    vartype : TType;
    bool    : PBoolean;
    int     : PInteger;
    float   : PFloat;
    str     : PStr;
    byte    : PByte;
  end;

  TParam = record
    paramtype : TType;
    bool      : Boolean;
    int       : Integer;
    float     : Single;
    str       : String;
    byte      : Byte;
  end;
  TParams = array of TParam;

  PProc      = procedure();
  PProcParam = procedure(const params : TParams);

  TCom = record
    com       : String;
    comtype   : TComType;
    v         : TVar;
    proc      : PProc;
    procparam : PProcParam;
    params    : TParams;
  end;

procedure RegVar(const command : String; const vartype : TType; const varpointer : pointer );
procedure RegProc(const command : String; const proc : pointer; const params : TParams = nil);
procedure Execute(const script : String; const fromfile : boolean = False);
procedure ExecuteScript(const params : TParams);

function Params(const p: array of TParam): TParams;
function P(paramtype : TType): TParam; overload;
function P(bool : Boolean): TParam; overload;
function P(int : Integer): TParam; overload;
function P(float : Single): TParam; overload;
function P(str : String): TParam; overload;

implementation

Uses
  Main,
  Log;

var
  script_coms : array of TCom;

function GetCommand(const command : String; var com : TCom): Boolean;
var
  i : integer;
begin
  result := false;
  for I := Low(script_coms) to High(script_coms) do
    if command = script_coms[i].com then
    begin
      Result := true;
      com := script_coms[i];
      Break;
    end;
end;

procedure CheckCommand(const command : String);
var
  c : TCom;
  i : Integer;
begin
  if GetCommand(command, c) then
    Print('Command ' + command + ' already exists', LT_ERROR);
  for i := 1 to length(command) do
    if not(command[i] in ['a'..'z', '_']) then
      Print('Command ' + command + ' contains illegal characters', LT_ERROR);
end;

procedure RegVar(const command : String; const vartype : TType; const varpointer : pointer );
var
  i : integer;
begin
  CheckCommand(lowercase(command));
  i := Length(script_coms);
  SetLength(script_coms, i+1);
  with script_coms[i] do
  begin
    com       := lowercase(command);
    comtype   := CT_VAR;
    v.vartype := vartype;
    case script_coms[i].v.vartype of
      T_BOOL  : v.bool  := PBoolean(varpointer);
      T_INT   : v.int   := PInteger(varpointer);
      T_FLOAT : v.float := PFloat(varpointer);
      T_STR   : v.str   := PStr(varpointer);
      T_BYTE  : v.byte  := PByte(varpointer);
    end;
  end;
end;

procedure RegProc(const command : String; const proc : pointer; const params : TParams);
var
  i : integer;
begin
  CheckCommand(lowercase(command));
  i := Length(script_coms);
  SetLength(script_coms, i+1);
  script_coms[i].com     := lowercase(command);
  script_coms[i].params  := params;
  if assigned(params) then
  begin
    script_coms[i].comtype := CT_PROCPARAM;
    script_coms[i].procparam := PProcParam(proc)
  end
  else
  begin
    script_coms[i].comtype := CT_PROC;
    script_coms[i].proc := PProc(proc);
  end;
end;

procedure Execute(const script : String; const fromfile : boolean = False);
var
  i,j  : integer;
  coms, split, params : TStringList;
  str  : String;
  c    : TCom;
  fp   : TFormatSettings;

const
  vpnames : array[0..4] of string = ('boolean', 'integer', 'float', 'string', 'byte');
  synerr  = 'Syntax error in ';

function StrToByte(const str : String): byte;
var
  i : byte;
begin
  i := StrToInt(str);
  if ((i < 0) or (i > 255)) then raise Exception.Create('');
  result := i;
end;

procedure SplitStr(const str : String; const delimiters : array of Char; const incldelimiters : boolean; var result : TStringList);
var
  i, j : Integer;
  tmp : String;
  delfound : boolean;
begin
  result.Clear();
  i := 1;
  tmp := '';
  while i <= length(str) do
  begin
    if str[i] = '"' then
    begin
      tmp := tmp + str[i];
      inc(i);
      while str[i] <> '"' do
      begin
        tmp := tmp + str[i];
        inc(i);
      end;
    end;

    delfound := false;
    for j := 0 to length(delimiters)-1 do
      if str[i] = delimiters[j] then
      begin
        delfound := true;
        break;
      end;

    if delfound then
    begin
      if tmp <> '' then result.Add(tmp);
      tmp := '';
      if incldelimiters then result.Add(delimiters[j]);
    end
    else
      tmp := tmp + str[i];

    inc(i);
  end;
  if tmp <> '' then result.Add(tmp);
end;

begin
  try
    fp.DecimalSeparator := '.';
    coms   := TStringList.Create();
    split  := TStringList.Create();
    params := TStringList.Create();

    //Preprocess
    i := 1;
    while i <= length(script) do
    begin
      //skip over comments.
      if script[i] = '{' then
      begin
        while script[i] <> '}' do
        begin
          inc(i);
          if i > length(script)-1 then
            raise Exception.Create('Unclosed comment');
        end;
        inc(i);
      end;

      //skip over strings when removing whitespace.
      if script[i] = '"' then
      begin
        str := str + script[i];
        inc(i);
        while script[i] <> '"' do
        begin
          if i > length(script) then
            raise Exception.Create('Unclosed string');
          str := str + script[i];
          inc(i);
        end;
      end;

      //add character that are not whitespace.
      if not(((script[i] = ' ') or (script[i] = #9) or (script[i] = #10) or
              (script[i] = #13) or (script[i] = #13#10))) then
        str := str + lowercase(script[i]);

      inc(i);
    end;

    //Parsing and execution
    SplitStr(str, [';'], false, coms);
    for i := 0 to coms.Count-1 do
    begin
      if coms[i] = '' then continue;

      SplitStr(coms[i], ['=', '(', ')'], true, split);
      if not(GetCommand(split[0], c)) then
        raise Exception.Create('Command ' + split[0] + ' does not exist');

      case c.comtype of
      CT_VAR:
      begin
        if split.Count <> 3 then
          raise Exception.Create(synerr + coms[i]);
        if split[1] <> '=' then
          raise Exception.Create(synerr + coms[i]);

        try
          case c.v.vartype of
          T_BOOL:  c.v.bool^ := StrToBool(split[2]);
          T_INT:   c.v.int^ := StrToInt(split[2]);
          T_FLOAT: c.v.float^ := StrToFloat(split[2], fp);
          T_STR:
          begin
            if (split[2][1] <> '"') or (split[2][length(split[2])] <> '"') then
              raise Exception.Create('');
            c.v.str^ := StringReplace(split[2], '"', '', [rfReplaceAll]);
          end;
          T_BYTE:  c.v.byte^ := StrToByte(split[2]);
          end;
        except
          raise Exception.Create('Value ' + split[2] + ' is not a proper ' + vpnames[integer(c.v.vartype)]);
        end;
      end;
      CT_PROC:
      begin
        if split.Count <> 3 then
          raise Exception.Create(synerr + coms[i]);
        if (split[1] <> '(') or (split[2] <> ')') then
          raise Exception.Create(synerr + coms[i]);
        c.proc();
      end;
      CT_PROCPARAM:
      begin
        if split.Count <> 4 then
          raise Exception.Create(synerr + coms[i]);
        if (split[1] <> '(') or (split[3] <> ')') then
          raise Exception.Create(synerr + coms[i]);

        SplitStr(split[2], [','], false, params);
        if params.Count <> length(c.params) then
          raise Exception.Create('Parameter count for ' + split[0] + ' is incorrect');

        for j := 0 to length(c.params)-1 do
        begin
          try
            case c.params[j].paramtype of
            T_BOOL:  c.params[j].bool  := StrToBool(params[j]);
            T_INT:   c.params[j].int   := StrToInt(params[j]);
            T_FLOAT: c.params[j].float := StrToFloat(params[j], fp);
            T_STR:
            begin
              if (params[j][1] <> '"') or (params[j][length(params[j])] <> '"') then
                raise Exception.Create('');
              c.params[j].str := StringReplace(params[j], '"', '', [rfReplaceAll]);
            end;
            T_BYTE:  c.params[j].byte  := StrToByte(params[j]);
            end;
          except
              raise Exception.Create('Value ' + params[j] + ' is not a proper ' + vpnames[integer(c.params[j].paramtype)]);
          end;
        end;
        c.procparam(c.params);
      end;
      end;
    end;
  except
    on E: Exception do
    begin
      if fromfile then
         raise Exception.Create(e.Message)
      else
         Print(e.Message, LT_WARNING);
    end;
  end;
  FreeAndNil(coms);
  FreeAndNil(split);
  FreeAndNil(params);
end;

procedure ExecuteScript(const params : TParams);
var
  sf : TStringList;
  path : String;
begin
  path :=  basedatadir + params[0].str;
  Print('Executing script (' + path + ')...');
  try
    sf := TStringList.Create();
    if Not(FileExists(path)) then
      raise Exception.Create('Script file ' + path + ' does not exist');
    sf.LoadFromFile(path);
    Execute(sf.text, true);
  except
    on E: Exception do
    begin
      Print('Script error: ' + e.Message, LT_WARNING);
    end;
  end;
  FreeAndNil(sf);
end;

function P(paramtype : TType): TParam; overload;
begin
  result.paramtype := paramtype;
end;

function P(bool : Boolean): TParam; overload;
begin
  result.paramtype := T_BOOL;
  result.bool := bool;
end;

function P(int : Integer): TParam; overload;
begin
  result.paramtype := T_INT;
  result.int := int;
end;

function P(float : Single): TParam; overload;
begin
  result.paramtype := T_FLOAT;
  result.float := float;
end;

function P(str : String): TParam; overload;
begin
  result.paramtype := T_STR;
  result.str := str;
end;

function P(byte : Byte): TParam; overload;
begin
  result.paramtype := T_BYTE;
  result.byte := byte;
end;

function Params(const p: array of TParam): TParams;
var
  i: Integer;
begin
  setLength(Result,Length(p));
  for i := 0 to High(p) do
    result[i] := p[i];
end;

procedure Help();
var
  com : String;
  i,j : Integer;
  f   : boolean ;
  v, p, vp : TStringList;

function TypeToStr(const t : TType): String;
begin
  case t of
    T_BOOL  : result := 'BOOL';
    T_INT   : result := 'INT' ;
    T_FLOAT : result := 'FLOAT';
    T_STR   : result := 'STR';
    T_BYTE  : result := 'BYTE';
  end;
end;

begin
  v  := TStringList.Create();
  p  := TStringList.Create();
  vp := TStringList.Create();
  Print('');
    for i := 0 to length(script_coms)-1 do
    begin
      com := script_coms[i].com;
      case script_coms[i].comtype of
      CT_VAR:
      begin
        com := com + ' = ' + TypeToStr(script_coms[i].v.vartype);
        v.Add( com );
      end;
      CT_PROC:
      begin
        com := com + '()';
        p.Add( com );
      end;
      CT_PROCPARAM:
      begin
        com := com + '(';
        f := true;
        for j := 0 to length(script_coms[i].params)-1 do
        begin
          if f then f := not(f) else com := com + ', ';
          com := com + TypeToStr(script_coms[i].v.vartype)
        end;
        com := com + ')';
        vp.Add( com );
      end;
      end;
    end;
  vp.sort(); v.sort(); p.sort();
  Print('Vars:');
  for i := 0 to v.Count-1 do Print('  ' + v.Strings[i]);
  Print('');
  Print('Functions:');
  for i := 0 to p.Count-1 do Print('  ' + p.Strings[i]);
  for i := 0 to vp.Count-1 do Print('  ' + vp.Strings[i]);
  FreeAndNil(v); FreeAndNil(vp);FreeAndNil(p);
  Print('');
end;

initialization
  RegProc('help', @Help);
  RegProc('executescript', @ExecuteScript, Params([P(T_STR)]));
finalization
  SetLength(script_coms, 0);
end.
