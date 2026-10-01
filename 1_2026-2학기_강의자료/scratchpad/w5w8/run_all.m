function run_all(outFile, weeks)
if nargin < 2, weeks = {'W05','W06','W07','W08'}; end
fid = fopen(outFile,'w'); fclose(fid);
for k = 1:numel(weeks)
    try
        evalc(sprintf('run_week(''%s'', ''%s'');', weeks{k}, outFile));
        fprintf('ok   %s\n', weeks{k});
    catch e
        fprintf('ERR  %s : %s\n', weeks{k}, e.message);
        f2 = fopen(outFile,'a');
        if f2 > 0, fprintf(f2, '\n##ERR## %s : %s\n', weeks{k}, e.message); fclose(f2); end
    end
end
fprintf('RUN_ALL DONE\n');
end
