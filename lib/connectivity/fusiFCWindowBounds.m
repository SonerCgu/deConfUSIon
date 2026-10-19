function [t0,t1,name]=fusiFCWindowBounds(s,TR,nT)
% Absolute recording times; optional length trims the selected period.
if nargin<2||isempty(TR)||~isfinite(TR)||TR<=0,TR=1;end
if nargin<3||isempty(nT)||~isfinite(nT),nT=inf;end
duration=double(nT)*double(TR);mode='whole';first=14;last=15;lengthMin=3;limit=false;
if isfield(s,'fcEpochMode'),mode=lower(char(s.fcEpochMode));end
if isfield(s,'fcInjStartMin'),first=max(0,double(s.fcInjStartMin));end
if isfield(s,'fcInjEndMin'),last=max(first,double(s.fcInjEndMin));end
if isfield(s,'fcEpochWinMin'),lengthMin=max(.01,double(s.fcEpochWinMin));end
if isfield(s,'fcUseEpochWin'),limit=logical(s.fcUseEpochWin);end
switch mode
 case 'pre'
  t0=0;t1=first*60;name='Before challenge';
  if limit,t0=max(0,(first-lengthMin)*60);end
 case 'during'
  assert(last>first,'deConfUSIon:FCWindowBounds','Challenge end must be later than start for During. No other interval was substituted.');
  t0=first*60;t1=last*60;name='During challenge';
  if limit,t1=min(t1,(first+lengthMin)*60);end
 case 'post'
  t0=last*60;t1=duration;name='After challenge';
  if limit,t1=min(t1,(last+lengthMin)*60);end
 otherwise
  t0=0;t1=duration;name='Whole recording';
end
t0=max(0,t0);t1=max(t0,min(t1,duration));
end
