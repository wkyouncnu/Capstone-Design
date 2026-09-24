# 서브시스템으로 묶기 — 최상위 화면은 "역할 상자 몇 개" 만 보이게

> [!important] 한 줄로
> **최상위에는 GNC 역할별 서브시스템만 두고, 로깅·그림은 선 없는 서브시스템으로 뺀다.**
> 블록을 펼쳐 놓고 `tidy_layout` 에 맡기면 선이 겹치고 태그가 엉뚱한 곳에 붙는다.

2026-09-15 W02 turtlesim 모델을 펼친 구조 → 서브시스템 구조로 다시 만들며 정리한 규칙이다.
결과: 최상위 블록 수 약 60 → 15, 겹침 0, 대각선 0, 시뮬레이션 수치는 한 자리도 안 바뀜.

---

## 1. 언제 묶는가

| 상황 | 판단 |
|---|---|
| 최상위 블록이 **20개를 넘는다** | 묶는다 |
| MATLAB Function 하나에 Constant 가 **4개 이상** 붙는다 | 그 함수 + 상수를 한 서브시스템으로 |
| To Workspace 가 여러 개 | `Logging` 서브시스템 하나로 |
| 실시간 그림 블록 (Clock · 상수 · extrinsic 함수) | `Animate` 서브시스템 하나로 |
| ROS Subscribe → Bus Selector → 유효성 래치 | `PoseSubscriber` 처럼 한 덩어리로 |
| Blank Message → Bus Assignment → Publish | `CmdPublisher` 처럼 한 덩어리로 |
| 블록이 10개 미만인 입문 모델 (구독만 하는 1단계 등) | **묶지 않는다.** 학생이 블록을 직접 봐야 한다 |

---

## 2. 최상위 배치 규칙

```
[From x][From y][From th][From valid]
        │
     Guidance ──> Control ──> Plant / CmdPublisher ──> [Goto x][Goto y][Goto th]
                    ^
               [From th]

  Animate (선 없음)      Logging (선 없음)      PoseSubscriber ──> [Goto ...]
```

- **왼쪽 → 오른쪽 = 유도 → 제어 → 추진기 → 운동모델** (SKILL.md 절대 규칙과 같다)
- 되먹임은 최상위의 **Goto/From 태그**로. 화면을 가로지르는 선을 만들지 않는다
- 로깅·그림 서브시스템은 **입출력 포트가 없다.** 안에서 From 태그로 받는다
- 두 모델(오프라인 / 실물)은 **같은 함수로 같은 서브시스템**을 만든다 → 바뀌는 상자는 하나뿐임이 그림으로 보인다

---

## 3. 생성 관용구 — 그대로 복사해 쓴다

```matlab
% 빈 서브시스템 — 기본으로 들어 있는 In1 -> Out1 을 지운다
function ss = newSub(m, name, pos)
    ss = [m '/' name];
    add_block('simulink/Ports & Subsystems/Subsystem', ss, 'Position', pos);
    delete_line(ss, 'In1/1', 'Out1/1');
    delete_block([ss '/In1']);
    delete_block([ss '/Out1']);
end

% 이름 붙은 포트 — 이름이 서브시스템 겉면에 그대로 찍힌다
function inP(ss, name, k)
    y = 40 + (k-1)*60;
    add_block('simulink/Sources/In1', [ss '/' name], 'Port', num2str(k), ...
              'Position', [20 y 50 y+14]);
end
function outP(ss, name, k)
    y = 40 + (k-1)*60;
    add_block('simulink/Sinks/Out1', [ss '/' name], 'Port', num2str(k), ...
              'Position', [900 y 930 y+14]);
end

% Goto 는 global — 다른 서브시스템 안의 From 이 받을 수 있게
function G(sys, tag, x, y)
    add_block('simulink/Signal Routing/Goto', [sys '/Go_' tag], ...
              'Position', [x y x+80 y+25], 'GotoTag', tag, 'TagVisibility','global');
end

% MATLAB Function — 서브시스템 경로를 그대로 넘기면 된다
function addFcn(sys, name, pos, code)
    add_block('simulink/User-Defined Functions/MATLAB Function', [sys '/' name], 'Position', pos);
    ch = sfroot().find('-isa','Stateflow.EMChart','Path',[sys '/' name]);
    ch.Script = code;
end
```

- 포트 이름은 **신호 이름과 같게** (`psi_ref`, `dist`, `mode`). 겉면만 보고 배선이 읽힌다
- 포트 순서 = 함수 인자 순서. 안쪽 선이 교차하지 않는다
- 서브시스템 **안**의 배치는 `tidy_layout` 이 `arrangeSystem` 에 맡긴다. 좌표는 대충 줘도 된다

---

## 4. 색은 역할표가 정한다

`_tools/gnc_roles.m` 에 모델 이름별 표가 있고, `paint_roles` 가 그것을 칠한다.
**이름의 부분 문자열로 색을 고르던 `tidy_layout.m` 의 `colorFor` 는 더 쓰지 않는다.**
`PoseNav` 의 `nav` 가 `plant` 로 걸려 초록이 되는 식의 사고가 있었다 — 이름을 바꾸면
색이 바뀌는 규칙은 유지할 수 없다.

```matlab
% _tools/gnc_roles.m
case 'W03_4_teleop'
    role = [GNC; {'TeleopPad','guidance'; 'OdomNav','ros'}];
```

- 표에 적는 것은 **최상위 블록뿐**이다. 안쪽 서브시스템은 부모 색을 물려받는다
- `Scope` · `Display` · `ToWorkspace` · `Goto` · `From` · `Terminator` 는
  적지 않아도 **언제나 회색**이다
- 표에 없는 모델은 관례 이름(`Guidance` · `InnerLoop` · `Thrusters` ·
  `MotionModel` · `CmdPublisher` · `PoseSubscriber` · `Animate` · `Logging`)이
  그대로 맞는다. 그래서 5\~7주차는 `case` 한 줄로 끝난다
- 새 이름을 쓰면 `gnc_roles.m` 에 `case` 를 추가한다. **고칠 곳은 그 한 파일뿐이다**

> [!important] 빠뜨렸는지는 `check_colour` 가 말해 준다
> 최상위에 있는데 표에 없는 서브시스템은 흰색으로 남고, 검사에 걸린다.
> 일부러 그렇게 두었다 — 조용히 아무 색이나 주는 것보다 낫다.

---

## 5. 이미 밟은 지뢰

| 증상 | 원인 | 조치 |
|---|---|---|
| 서브시스템 안에 쓸모없는 `In1 → Out1` 선이 남음 | 라이브러리 Subsystem 은 기본 포트 2개를 갖고 온다 | `newSub` 로 만든 직후 지운다 |
| `Logging` 안의 From 이 `Goto not found` | Goto 기본 `TagVisibility` 가 **local** | 모든 Goto 를 `global` 로 |
| 펼친 모델에서 `[w]` Goto 가 `[x]` 옆에 겹쳐 붙음 | 출력이 두 갈래(포트 + 태그)인 블록이 많으면 `tidy_layout` 이 받기 블록을 한 높이로 몰아넣는다 | 태그 분기를 **서브시스템 안**으로 옮긴다 |
| 제어 서브시스템에 입력선이 대각선 | 포트 순서가 윗단 출력 순서와 다르다 | 겉면 포트 순서를 윗단 출력 순서와 맞춘다 |
| 서브시스템 그림을 문서에 넣고 싶다 | — | `print('-s모델/서브시스템','-dpng','-r100', 파일)` |

---

## 6. 검증 — 묶기 전후로 같은 숫자가 나와야 한다

1. 묶기 **전** 모델로 `sim` → 핵심 수치 기록 (예: 최종 오차, 도착 시각)
2. 서브시스템 구조로 다시 생성 → 같은 `sim`
3. **수치가 소수점까지 같아야 한다.** 다르면 배선 순서가 바뀐 것이다
4. `tidy_all` → 겹침 0, 미연결 포트 0 (`LookUnderMasks','all'` 로 안쪽까지)
5. 최상위 + 서브시스템마다 PNG 를 뽑아 **눈으로 본다**

```matlab
ph = find_system(m,'FindAll','on','LookUnderMasks','all','Type','port');
n  = sum(arrayfun(@(h) get_param(h,'Line') < 0, ph));   % 0 이어야 한다
```
