unit Log;

interface

uses
  {$IFDEF Win32}
  Windows,
  {$ENDIF}
  Classes,
  SysUtils;

type
  TLogType = (LT_MESSAGE, LT_WARNING, LT_ERROR);

var
  log_text  : TStringList;

procedure Print(const logmessage : String; const logtype : TLogType = LT_MESSAGE);

implementation

uses
  Main;

const
  LOG_FILE = 'log.txt';

procedure AddLine(const logmessage : String);
begin
  WriteLn( logmessage );
  log_text.Add( logmessage );
  log_text.SaveToFile( basedir + LOG_FILE );
end;

procedure Print(const logmessage : String; const logtype : TLogType = LT_MESSAGE);
begin
  case logtype of
    LT_MESSAGE : AddLine( logmessage );
    LT_WARNING : AddLine( 'Warning: ' + logmessage );
    LT_ERROR   : begin
                  AddLine( 'Error: ' + logmessage );
                  {$IFDEF Win32}
                    MessageBox(0, 'An error occurred. See the log for more detail.', 'Error', 0 or 16);
                  {$ENDIF}
                  quit := true;
                 end;
  end;
end;

initialization
  log_text := TStringList.Create();
finalization
  FreeAndNil(log_text);
end.
