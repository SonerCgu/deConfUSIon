function tests=testDataLoadProgress
tests=functiontests(localfunctions);
end
function setupOnce(test)
deConfUSIon_setup();test.TestData.root=tempname;mkdir(test.TestData.root);
end
function teardownOnce(test),rmdir(test.TestData.root,'s');end
function testPartialRawMATPreservesImageAndMetadata(test)
IQR=reshape(single(1:5*8*4*40),5,8,4,40);TR=.48;
metadata=struct('voxelSizeUm',[100 150 150],'note','original geometry'); %#ok<NASGU>
file=fullfile(test.TestData.root,'raw.mat');save(file,'IQR','TR','metadata','-v7.3');
fractions=[];messages={};[actual,meta]=loadFUSIData(file,[],@record);
[expected,expectedMeta]=loadFUSIData(file,[]);
verifyEqual(test,actual,expected);verifyEqual(test,meta,expectedMeta);
verifyEqual(test,actual.I,IQR);verifyEqual(test,actual.TR,.48);
verifyEqual(test,fractions(1),0);verifyEqual(test,fractions(end),1);
known=fractions(isfinite(fractions));verifyGreaterThanOrEqual(test,min(diff(known)),0);
verifyGreaterThanOrEqual(test,sum(contains(messages,'frames')),8);
    function record(f,message),fractions(end+1)=f;messages{end+1}=message;end
end
function testStructuredSavedDataPreservesHistory(test)
newData=struct('I',rand(5,6,3,24,'single'),'TR',.48,'PSC',rand(5,6,3,24,'single'), ...
    'preprocessing',struct('method','PCA','componentsRemoved',1)); %#ok<NASGU>
file=fullfile(test.TestData.root,'processed.mat');save(file,'newData','-v7.3');
fractions=[];[actual,meta]=loadFUSIData(file,[],@record);[expected,expectedMeta]=loadFUSIData(file,[]);
verifyEqual(test,actual,expected);verifyEqual(test,meta,expectedMeta);
verifyTrue(test,any(isnan(fractions)));verifyEqual(test,fractions(end),1);
    function record(f,~),fractions(end+1)=f;end
end
function testClassicMATReportsReadAndCompletion(test)
I=rand(5,6,24,'single');TR=1;file=fullfile(test.TestData.root,'classic.mat');save(file,'I','TR','-v7');
fractions=[];actual=loadFUSIData(file,[],@record);
verifyEqual(test,actual.I,I);verifyTrue(test,any(isnan(fractions)));verifyEqual(test,fractions(end),1);
    function record(f,~),fractions(end+1)=f;end
end
function testPartialReadCancellationDoesNotModifySource(test)
I=rand(5,6,4,24,'single');file=fullfile(test.TestData.root,'cancel.mat');save(file,'I','-v7.3');
verifyError(test,@()fusiLoadMatVariables(file,{'I'},@cancel),'deConfUSIon:ProcessingCancelled');
saved=load(file,'I');verifyEqual(test,saved.I,I);
    function cancel(f,~)
        if f>0&&f<1,error('deConfUSIon:ProcessingCancelled','Cancelled test read.');end
    end
end
function testPartialComplexAndLogicalArraysStayExact(test)
A=complex(rand(4,5,3,12,'single'),rand(4,5,3,12,'single'));
B=rand(4,5,3,12)>.5;file=fullfile(test.TestData.root,'types.mat');save(file,'A','B','-v7.3');
actual=fusiLoadMatVariables(file,{'A','B'},@(~,~)[]);
verifyEqual(test,actual.A,A);verifyEqual(test,actual.B,B);
end
function testProgressUnknownStageAndCancellation(test)
h=deConfUSIon_ui('progress','Loading dataset');guard=onCleanup(@()deConfUSIon_ui('progressclose',h)); %#ok<NASGU>
deConfUSIon_ui('progressupdate',h,.25,'Reading frames...');
verifyTrue(test,contains(get(findall(h,'Tag','ProcessingStatus'),'String'),'25%'));
deConfUSIon_ui('progressupdate',h,NaN,'Reading saved dataset from disk...');
verifyEqual(test,get(findall(h,'Tag','ProcessingStatus'),'String'),'Reading saved dataset from disk...');
verifyFalse(test,contains(get(findall(h,'Tag','ProcessingStatus'),'String'),'NaN'));
setappdata(h,'CancelProcessing',true);
verifyError(test,@()deConfUSIon_ui('progressupdate',h,.5,'Preparing data...'),'deConfUSIon:ProcessingCancelled');
end
