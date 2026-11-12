function n = finishA3(m, chain, boxes)
%  단마다 똑같이 거치는 마무리 — 배치 · 색 · 선 손질 · 검사 · 그림 내보내기
%
%  6주차의 finishStage 와 같다. 바뀐 것은 콜백을 다는 함수 이름 하나다.
%
%  순서가 중요하다.
%    (1) mss_style 은 선 손질 앞이어야 한다. 뒤에 두면 게인이 기본 크기로
%        되돌아가 화면에 -K- 만 남는다
%    (2) nudge_labels 는 모델을 **닫은 뒤** 부른다. 이 도구가 스스로 열고
%        저장을 번갈아 하므로, 저장하지 않은 변경이 메모리에 남아 있으면 날아간다
    lay_chain(m, chain, 'Boxes', boxes, 'Wrap', 5);

    load_system(m);
    straighten_chain(m, chain);
    flatten_lines(m);
    paint_roles(m);
    check_colour(m);
    mss_style(m);  save_system(m);  close_system(m, 0);

    settle_links(m);

    load_system(m);
    snug_tags(m);
    pack_boxes(m, boxes);
    lay_links(m);                 %  남은 세 번 꺾인 선만 통로 하나로 다시 긋는다
    scope_legend(m);
    A3_set_callbacks(m);          %  InitFcn · StopFcn — 직접 Run 해도 자기 단으로 돈다
    save_system(m);  close_system(m, 0);

    nudge_labels(m);

    load_system(m);
    n = check_lines(m, false);
    export_diagram(m);
    close_system(m, 0);
end
