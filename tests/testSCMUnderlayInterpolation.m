function tests=testSCMUnderlayInterpolation
tests=functiontests(localfunctions);
end

function testSharpPixelsOnlyChangesUnderlay(testCase)
assumeTrue(testCase,usejava('awt'));
addpath(fileparts(fileparts(mfilename('fullpath'))));deConfUSIon_setup();
PSC=ones(12,14,3,31,'single');PSC(4:8,5:10,:,:)=20;
baseline=struct('mode','sec','start',0,'end',20,'sigStart',60,'sigEnd',200);
f=SCM_gui(PSC,ones(12,14,3),10,struct(),baseline,31,'Interpolation regression');
cleanup=onCleanup(@()delete(f)); %#ok<NASGU>
overlay=findall(f,'Tag','SCM_OverlayImage');underlay=findall(f,'Tag','SCM_UnderlayImage');
checkbox=findall(f,'Tag','SCM_SharpPixels');reader=getappdata(f,'FUSIUnderlayData');
initial=reader();values=overlay.CData;alpha=overlay.AlphaData;
verifyEqual(testCase,checkbox.Value,1);verifyEqual(testCase,overlay.Interpolation,'nearest');
for value=[0 1 0 1]
    checkbox.Value=value;callback=checkbox.Callback;callback(checkbox,[]);
    expected='bilinear';if value,expected='nearest';end
    verifyEqual(testCase,underlay.Interpolation,expected);
    verifyEqual(testCase,overlay.Interpolation,'nearest');
    verifyEqual(testCase,overlay.CData,values);verifyEqual(testCase,overlay.AlphaData,alpha);
    actual=reader();verifyEqual(testCase,actual.PSC,initial.PSC);
    verifyEqual(testCase,actual.underlay,initial.underlay);
    verifyEqual(testCase,actual.appearance,initial.appearance);
end
end
