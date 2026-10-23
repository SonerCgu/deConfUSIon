function fusiLightSuiteLog(level,context,message,varargin)
% MATLAB Command Window supports bold <strong> text without extra toolboxes.
if nargin<3,message=context;context=struct();end
if ~isempty(varargin),message=sprintf(message,varargin{:});end
if iscell(message),message=strjoin(message,newline);end
id=fusiLightSuiteIdentity(context);level=upper(char(level));stream=1;
if any(strcmp(level,{'ERROR','FAILED'})),stream=2;end
fprintf(stream,'\n[%s] <strong>LIGHTSUITE | %s</strong> | %s\n%s\n', ...
    datestr(now,'HH:MM:SS'),level,id.label,char(message));
end
