REPORT zflight_demo.

* Flight occupancy: a selection screen, then screen 100 with an ALV grid.
* Double click a flight to see its free seats, use Details for the
* selected row, Back (F3) to return to the selection screen.

TABLES zflight_demo.

TYPES: BEGIN OF ty_flight,
         carrid    TYPE zflight_demo-carrid,
         carrname  TYPE zcarr_demo-carrname,
         connid    TYPE zflight_demo-connid,
         fldate    TYPE zflight_demo-fldate,
         planetype TYPE zflight_demo-planetype,
         price     TYPE zflight_demo-price,
         currency  TYPE zflight_demo-currency,
         seatsmax  TYPE zflight_demo-seatsmax,
         seatsocc  TYPE zflight_demo-seatsocc,
         seatsfree TYPE i,
         occupancy TYPE p LENGTH 5 DECIMALS 1,
       END OF ty_flight.
TYPES ty_flights TYPE STANDARD TABLE OF ty_flight WITH DEFAULT KEY.

SELECT-OPTIONS s_carr FOR zflight_demo-carrid.
SELECT-OPTIONS s_date FOR zflight_demo-fldate.
PARAMETERS p_free AS CHECKBOX DEFAULT abap_true.

CLASS lcl_handler DEFINITION.
  PUBLIC SECTION.
    CLASS-METHODS on_toolbar FOR EVENT toolbar OF cl_gui_alv_grid
      IMPORTING e_object.
    CLASS-METHODS on_user_command FOR EVENT user_command OF cl_gui_alv_grid
      IMPORTING e_ucomm.
    CLASS-METHODS on_double_click FOR EVENT double_click OF cl_gui_alv_grid
      IMPORTING e_row.
    CLASS-METHODS describe
      IMPORTING iv_index TYPE i.
ENDCLASS.

DATA gt_flights TYPE ty_flights.
DATA gt_fieldcat TYPE lvc_t_fcat.
DATA go_container TYPE REF TO cl_gui_custom_container.
DATA go_grid TYPE REF TO cl_gui_alv_grid.
DATA gv_ok_code TYPE sy-ucomm.
DATA gv_state TYPE c LENGTH 70.

CLASS lcl_handler IMPLEMENTATION.
  METHOD on_toolbar.
    APPEND VALUE #( butn_type = cntb_btype_sep ) TO e_object->mt_toolbar.
    APPEND VALUE #( function  = 'DETAILS'
                    icon      = icon_detail
                    quickinfo = 'Show free seats of the selected flight'
                    text      = 'Details' ) TO e_object->mt_toolbar.
  ENDMETHOD.

  METHOD on_user_command.
    DATA lt_rows TYPE lvc_t_row.

    IF e_ucomm <> 'DETAILS'.
      RETURN.
    ENDIF.
    go_grid->get_selected_rows( IMPORTING et_index_rows = lt_rows ).
    READ TABLE lt_rows INTO DATA(ls_row) INDEX 1.
    IF sy-subrc <> 0.
      gv_state = 'Select a flight first'.
      RETURN.
    ENDIF.
    describe( ls_row-index ).
  ENDMETHOD.

  METHOD on_double_click.
    describe( e_row-index ).
  ENDMETHOD.

  METHOD describe.
    READ TABLE gt_flights INTO DATA(ls_flight) INDEX iv_index.
    IF sy-subrc <> 0.
      RETURN.
    ENDIF.
    gv_state = |{ ls_flight-carrid } { ls_flight-connid } on { ls_flight-fldate DATE = ISO }: | &&
               |{ ls_flight-seatsfree } of { ls_flight-seatsmax } seats free|.
  ENDMETHOD.
ENDCLASS.

START-OF-SELECTION.
* The open-abap-gui host passes an empty select-option as I EQ space, and a
* filled low and high as EQ instead of BT. SAP does neither, so these lines
* change nothing on a real system.
  DELETE s_carr WHERE low IS INITIAL AND high IS INITIAL.
  DELETE s_date WHERE low IS INITIAL AND high IS INITIAL.
  LOOP AT s_carr ASSIGNING FIELD-SYMBOL(<ls_carr>) WHERE option = 'EQ' AND high IS NOT INITIAL.
    <ls_carr>-option = 'BT'.
  ENDLOOP.
  LOOP AT s_date ASSIGNING FIELD-SYMBOL(<ls_date>) WHERE option = 'EQ' AND high IS NOT INITIAL.
    <ls_date>-option = 'BT'.
  ENDLOOP.

* Two reads instead of a JOIN: the transpiler does not yet rewrite alias~field
* on the right side of ON or inside IN, so the joined SELECT finds nothing.
  DATA lt_airlines TYPE HASHED TABLE OF zcarr_demo WITH UNIQUE KEY carrid.

  SELECT carrid, connid, fldate, planetype, price, currency, seatsmax, seatsocc
    FROM zflight_demo
    WHERE carrid IN @s_carr
      AND fldate IN @s_date
    ORDER BY carrid, connid, fldate
    INTO CORRESPONDING FIELDS OF TABLE @gt_flights.

  SELECT * FROM zcarr_demo INTO TABLE @lt_airlines.

  LOOP AT gt_flights ASSIGNING FIELD-SYMBOL(<ls_flight>).
    <ls_flight>-carrname = VALUE #( lt_airlines[ carrid = <ls_flight>-carrid ]-carrname OPTIONAL ).
    <ls_flight>-seatsfree = <ls_flight>-seatsmax - <ls_flight>-seatsocc.
    IF <ls_flight>-seatsmax > 0.
      <ls_flight>-occupancy = <ls_flight>-seatsocc * 100 / <ls_flight>-seatsmax.
    ENDIF.
  ENDLOOP.
  IF p_free = abap_true.
    DELETE gt_flights WHERE seatsfree <= 0.
  ENDIF.

  IF gt_flights IS INITIAL.
    MESSAGE 'No flights match the selection' TYPE 'S' DISPLAY LIKE 'E'.
    RETURN.
  ENDIF.

  CALL SCREEN 100.

MODULE status_0100 OUTPUT.
  SET PF-STATUS 'MAIN'.
  SET TITLEBAR 'MAIN' WITH lines( gt_flights ).
  IF go_container IS INITIAL.
    go_container = NEW #( container_name = 'CC_GRID' ).
    go_grid = NEW #( i_parent      = go_container
                     i_appl_events = abap_true ).
    gt_fieldcat = VALUE #(
      ( fieldname = 'CARRID'    coltext = 'Airline'   outputlen = 7 )
      ( fieldname = 'CARRNAME'  coltext = 'Name'      outputlen = 18 )
      ( fieldname = 'CONNID'    coltext = 'Flight'    outputlen = 6 )
      ( fieldname = 'FLDATE'    coltext = 'Date'      outputlen = 10 datatype = 'DATS' )
      ( fieldname = 'PLANETYPE' coltext = 'Plane'     outputlen = 10 )
      ( fieldname = 'PRICE'     coltext = 'Price'     outputlen = 12 cfieldname = 'CURRENCY' )
      ( fieldname = 'CURRENCY'  coltext = 'Curr.'     outputlen = 5 )
      ( fieldname = 'SEATSMAX'  coltext = 'Seats'     outputlen = 6 )
      ( fieldname = 'SEATSOCC'  coltext = 'Occupied'  outputlen = 8 )
      ( fieldname = 'SEATSFREE' coltext = 'Free'      outputlen = 6 )
      ( fieldname = 'OCCUPANCY' coltext = 'Occ. %'    outputlen = 7 ) ).
    SET HANDLER lcl_handler=>on_toolbar FOR go_grid.
    SET HANDLER lcl_handler=>on_user_command FOR go_grid.
    SET HANDLER lcl_handler=>on_double_click FOR go_grid.
    go_grid->set_table_for_first_display(
      EXPORTING
        is_layout       = VALUE lvc_s_layo( zebra = abap_true sel_mode = 'A' )
      CHANGING
        it_outtab       = gt_flights
        it_fieldcatalog = gt_fieldcat ).
    gv_state = 'Double click a flight, or select one and press Details'.
  ENDIF.
ENDMODULE.

MODULE user_command_0100 INPUT.
  CASE gv_ok_code.
    WHEN 'BACK' OR 'EXIT' OR 'CANCEL'.
      CLEAR gv_ok_code.
      LEAVE TO SCREEN 0.
  ENDCASE.
  CLEAR gv_ok_code.
ENDMODULE.
