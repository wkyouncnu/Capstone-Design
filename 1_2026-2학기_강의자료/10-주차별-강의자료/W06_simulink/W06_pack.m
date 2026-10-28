function Z = W06_pack(out)
% W06_PACK  실행 결과(out) 에서 대조에 쓰는 신호만 뽑아 한 구조체로
%   오프라인과 VRX 가 같은 Logging 상자를 쓰므로 둘의 결과를 같은 꼴로 다룰 수 있다
Z = struct('t', out.log_x_n.Time, 'x', out.log_x_n.Data, 'y', out.log_y_n.Data, ...
           'psi', out.log_psi.Data, 'u', out.log_u.Data, 'v', out.log_v.Data, ...
           'FL', out.log_FL.Data, 'FR', out.log_FR.Data, 'FB', out.log_FB.Data);
end
