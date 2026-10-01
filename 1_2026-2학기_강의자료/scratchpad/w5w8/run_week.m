function run_week(wk, outFile)
%RUN_WEEK  주차 setup 을 auto-run 으로 돌리고 화면 출력을 파일에 적는다.
%   setup 스크립트는 첫 줄에서 clear 를 부른다. 함수 안에서 그냥 부르면 이 함수의
%   작업공간까지 지워지므로, base 작업공간에서 돌리고 출력만 받아 온다.
setappdata(0, 'runWeekOut', outFile);
setappdata(0, 'runWeekWk',  wk);
root = 'C:\Users\admin\Dropbox\캡스톤디자인\1_2026-2학기_강의자료\10-주차별-강의자료';
cd(fullfile(root, [wk '_simulink']));
bdclose('all');

s = evalc(sprintf('evalin(''base'', ''clear; %s_setup;'');', wk));

o = getappdata(0, 'runWeekOut');
w = getappdata(0, 'runWeekWk');
FID = fopen(o, 'a');
fprintf(FID, '\n########## %s auto-run ##########\n%s\n', w, s);
fclose(FID);
close all force;
fprintf('run %s done\n', w);
end
