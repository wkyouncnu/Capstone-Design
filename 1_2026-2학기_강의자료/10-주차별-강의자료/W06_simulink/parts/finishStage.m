function n = finishStage(m, chain, boxes)
%  단계마다 똑같이 거치는 마무리 — 배치 · 색 · 선 손질 · 검사 · 그림 내보내기
%
%  순서가 중요하다.
%    (1) mss_style 은 arrangeSystem 뒤·선 손질 앞이어야 한다. 앞에 두면
%        게인이 기본 크기로 되돌아가 -K- 가 남는다 (스킬 references/tidy.md).
%    (2) nudge_labels 는 모델을 **닫은 뒤** 부른다. 이 도구가 스스로 열고
%        save_system·settle_links·check_lines 를 번갈아 돌리므로, 저장하지
%        않은 변경이 메모리에 남아 있으면 그 사이에 날아간다.
    lay_chain(m, chain, 'Boxes', boxes, 'Wrap', 4);

    load_system(m);
    straighten_chain(m, chain);   %  이웃 포트 높이를 맞춰 바로 잇는 선을 직선으로
    flatten_lines(m);             %  높이가 같아졌는데 아직 돌아가는 선을 곧게 다시
    paint_roles(m);
    check_colour(m);
    mss_style(m);  save_system(m);  close_system(m, 0);

    settle_links(m);

    load_system(m);
    snug_tags(m);
    pack_boxes(m, boxes);
    scope_legend(m);
    save_system(m);  close_system(m, 0);

    %  이름표가 가려진 것·이름표 위를 지나는 선을 블록을 비켜서 푼다.
    %  지적 수가 줄어든 자리만 남기므로 몇 번을 돌려도 손해가 없다
    nudge_labels(m);

    load_system(m);
    n = check_lines(m, false);
    export_diagram(m);
    close_system(m, 0);
end
