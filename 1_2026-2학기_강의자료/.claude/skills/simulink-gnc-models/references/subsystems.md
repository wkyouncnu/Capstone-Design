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
  — 되먹임이 **없을** 때만이다. 안쪽에서 되먹임을 만드는 고리는 §3-1 순서로 손수 앉힌다

---

## 3-1. 되먹임이 있는 서브시스템 — 안쪽은 **놓는 순서**가 있다

> [!important] 한 줄로
> `arrangeSystem` 에 맡겨도 되는 것은 **되먹임이 없는** 서브시스템뿐이다.
> 속도 PI 처럼 안에서 되먹임을 만드는 고리는 네 가지를 지켜 앉힌다.

2026-10-15 6주차 8단(NED 좌표계 위치제어)의 안쪽 고리를 처음 만들었을 때
`check_lines` 가 9건(겹침 7 · 블록관통 2)을 물었다. 블록 자리를 다시 잡아 0 으로
만든 순서가 아래다.

1. **되먹임을 만드는 블록은 도면 아래에 둔다.**
   합산점이 `'|+-'` 이므로 되먹임은 **2번(아래) 포트**로 든다. 되먹임을 만드는
   블록(측정 속도를 NED 로 돌리는 `ToNED` 등)이 위에 있으면 선이 사슬을 거슬러
   내려와 합산점 아래 통로를 가로지른다.

2. **여러 곳이 쓰는 신호와 되먹임 가닥은 태그로 푼다.**
   `drop_tag(ss, src, k, 이름)` → `feed_from(ss, 이름, dst, k)`. 선수각처럼 세
   블록이 함께 쓰는 신호를 선으로 뻗으면 중간 블록을 관통한다. 서브시스템 안에서만
   쓰는 태그이므로 최상위 태그와 겹치지 않게 `psi_in` 처럼 꼬리를 붙인다.

3. **입력 포트의 y 를 받는 포트 높이에 맞춘다.** 계산하지 않고 `port_xy` 로 읽는다.

   ```matlab
   pin = {'xdot_cmd','ErrXd',1; 'u','ToNED',1; 'r','Kd_rate',1};
   for k = 1:size(pin,1)
       p = port_xy(ss, pin{k,2}, 'Inport', pin{k,3});
       set_param([ss '/' pin{k,1}], 'Position', [60 p(2)-10 90 p(2)+10]);
   end
   ```

   선이 수평 직선 한 토막이 된다. 포트를 한 열(x = 60)에 쌓아도 세로 통로를
   나눠 쓰지 않으므로 겹치지 않는다.

4. **이미 0 을 받은 기하는 x 만 평행이동해 다시 쓴다.**
   8단의 선수각 사슬은 5단(`addInnerLoop`)의 좌표를 오른쪽으로 270 px 옮긴 것이다.
   같은 모양이면 같은 검사 결과가 나온다 — 새로 앉히면 새로 걸린다.

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
  그대로 맞는다. 그래서 5\~8주차는 `case` 한 줄로 끝난다
- 새 이름을 쓰면 `gnc_roles.m` 에 `case` 를 추가한다. **고칠 곳은 그 한 파일뿐이다**

> [!important] 빠뜨렸는지는 `check_colour` 가 말해 준다
> 최상위에 있는데 표에 없는 서브시스템은 흰색으로 남고, 검사에 걸린다.
> 일부러 그렇게 두었다 — 조용히 아무 색이나 주는 것보다 낫다.

---

## 5. 이미 겪은 것

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
