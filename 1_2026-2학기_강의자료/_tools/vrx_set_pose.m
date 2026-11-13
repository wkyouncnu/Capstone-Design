function ok = vrx_set_pose(psi_ned, enu_xyz, partition, world, model, distro)
%VRX_SET_POSE  가제보에 떠 있는 모델을 **주어진 위치·선수각으로 옮겨 세운다**
%
%   ok = vrx_set_pose(0, [-532 200 0.1], 'a3', 'sydney_regatta')
%
%   왜 필요한가 — (1) **스폰 선수각이 오프라인 초기값과 다르다**
%     VRX 의 competition.launch.py 가 WAM-V 를 ENU yaw 1.0 rad 로 놓는다
%       Model('wamv', 'wam-v', [-532, 200, 0, 0, 0, 1])
%     NED 로는 psi0 = 90 - 57.296 = 32.704 deg 다. 오프라인 모델은 psi_init 을
%     초기값으로 넣으므로 선수각 오차 0 에서 출발한다. 둘을 그대로 비교하면
%     **환경 차이가 아니라 출발 자세 차이**를 재는 것이 된다
%       1단(순수 횡이동) 에서 특히 치명적임 — psi_d = 0 이므로 배가 먼저
%       32.7 deg 를 돌아야 한다. 그 동안 횡력이 북쪽 성분을 가져 x 가 부풀고,
%       선수각이 수렴하면서 되돌아온다. "순수 횡이동" 이 아니게 된다
%
%   왜 필요한가 — (2) **앞 실험이 끝난 자리에서 다음 실험이 시작된다**
%     set_pose 를 쓰지 않으면 1단이 12 m 동쪽으로 간 자리에서 2단이 출발한다.
%     주차 자료의 원칙 "실험 간 초기화" 를 어기는 것이고, 측정값을 서로
%     견줄 수 없게 된다. 위치도 **스폰 지점으로 되돌린다**
%
%   왜 월드 파일을 고치지 않는가
%     competition.launch.py 는 vrx 상류 패키지의 파일이고 3주차 자료가 같이
%     쓴다. 한 부록 때문에 공용 파일을 고치지 않는다 — 실행 쪽에서 맞춘다
%
%   입력
%     psi_ned    목표 선수각 [rad, NED. 0 = 북]
%     enu_xyz    목표 위치 [ENU x y z]. z 는 오도메트리에서 읽은 현재 값을
%                그대로 넘긴다 (0 을 주면 선체가 물에 잠겼다 튀어 오른다)
%     partition  GZ_PARTITION (기본 'a3')
%     world      세계 이름 (기본 'sydney_regatta')
%     model      모델 이름 (기본 'wamv')
%
%   무엇을 부르는가
%     /world/<world>/set_pose   gz.msgs.Pose -> gz.msgs.Boolean
%     ENU yaw = pi/2 - psi_ned 이고, 쿼터니언은 z 축 회전 하나다
%
%   유의 사항
%     속도는 0 으로 되돌지 않는다. 출발 직전(정지 상태)에만 쓸 것
%     옮긴 뒤 물이 출렁인다 — 부른 뒤 3 초쯤 기다려 가라앉힌다
%     되읽을 때는 **구독을 새로 만들 것.** receive 는 쌓인 옛 메시지부터
%     꺼내므로, 옛 구독으로 읽으면 옮기기 전의 자세를 본다
%
%   > 오류 메시지 없이 실패하는 두 가지 (2026-11-13 실측)
%     (1) 모델 이름의 큰따옴표 — MATLAB system() 은 명령 전체를 큰따옴표로
%         감싸 cmd 에 넘긴다. req 안의 "wamv" 가 그 따옴표를 **먼저 닫아**
%         요청이 깨진다. `\"wamv\"` 로 이스케이프해야 한다
%     (2) gz service 는 **파싱에 실패해도 `data: true` 를 찍는다.** 이름이
%         빈 요청이 그대로 접수되고 배는 그대로 서 있다. 그래서 아래 판정은
%         `data: true` 만 보지 않고 protobuf ERROR 가 없는지도 본다

    if nargin < 3 || isempty(partition), partition = 'a3';             end
    if nargin < 4 || isempty(world),     world     = 'sydney_regatta'; end
    if nargin < 5 || isempty(model),     model     = 'wamv';           end
    if nargin < 6 || isempty(distro),    distro    = 'Ubuntu-22.04';   end

    yaw_enu = pi/2 - psi_ned;                 % NED 선수각 -> ENU yaw
    qz = sin(yaw_enu/2);  qw = cos(yaw_enu/2);

    %  \" 로 이스케이프 — 그냥 " 를 쓰면 cmd 가 명령을 거기서 끊는다 (위 참조)
    req = sprintf(['name: \\"%s\\", position: {x: %.6f, y: %.6f, z: %.6f}, ' ...
                   'orientation: {x: 0, y: 0, z: %.9f, w: %.9f}'], ...
                  model, enu_xyz(1), enu_xyz(2), enu_xyz(3), qz, qw);

    sh = ['export GZ_PARTITION=' partition '; ' ...
          'gz service -s /world/' world '/set_pose' ...
          ' --reqtype gz.msgs.Pose --reptype gz.msgs.Boolean' ...
          ' --timeout 3000 --req ''' req ''' 2>&1'];

    [st, txt] = system(['wsl.exe -d ' distro ' -e bash -lc "' sh '"']);

    %  'data: true' 만 보면 안 된다 — 파싱이 깨져도 그 줄은 찍힌다
    ok = (st == 0) && contains(txt, 'data: true') && ~contains(txt, 'ERROR');
    if ok
        fprintf(['    출발 자세를 맞췄습니다 — ENU (%.1f, %.1f) · ' ...
                 '선수각 %.1f deg (ENU yaw %.1f deg)\n'], ...
                enu_xyz(1), enu_xyz(2), rad2deg(psi_ned), rad2deg(yaw_enu));
        pause(3);                             % 물이 가라앉을 시간
    else
        fprintf(2, '    set_pose 가 듣지 않았습니다 — 응답: %s\n', strtrim(txt));
        fprintf(2, '    GZ_PARTITION=%s · 세계 %s · 모델 %s 를 확인할 것\n', ...
                partition, world, model);
    end
end
