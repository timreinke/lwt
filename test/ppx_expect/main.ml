let test_directory = "cases"

let _read_file name =
  let buffer = Buffer.create 4096 in
  let channel = open_in name in

  try
    let rec read () =
      try input_char channel |> Buffer.add_char buffer; read ()
      with End_of_file -> ()
    in
    read ();
    close_in channel;

    Buffer.contents buffer

  with exn ->
    close_in_noerr channel;
    raise exn

let _command_failed ?status command =
  match status with
  | None -> Printf.sprintf "'%s' did not exit" command |> failwith
  | Some v -> Printf.sprintf "'%s' failed with status %i" command v |> failwith

let _run_int command =
  match Unix.system command with
  | Unix.WEXITED v -> v
  | _ -> _command_failed command

let run command =
  let v = _run_int command in
  if v <> 0 then _command_failed command ~status:v

let diff reference result =
  let command = Printf.sprintf "diff -au %s %s" reference result in
  let status = _run_int (command ^ " > /dev/null") in
  match status with
  | 0 -> ()
  | 1 ->
    let _ : int =_run_int (command ^ " > delta") in
    let delta = _read_file "delta" in
    Printf.sprintf "> %s:\n\n%s" command delta
    |> failwith
  | _ -> _command_failed command ~status

let run_test name =
  let ml_name = name ^ ".ml" in
  let expect_name = name ^ ".expect" in
  let fixed_name = name ^ ".fixed" in
  let command = Printf.sprintf "ocaml -noinit %s 2> %s" ml_name fixed_name in
  let ocaml_return_code = _run_int command in
  begin if ocaml_return_code = 0 then
      failwith (Printf.sprintf "Unexpected toplevel return code: %d" ocaml_return_code)
  end;
  diff expect_name fixed_name

let () =
  let test_cases =
    Sys.readdir test_directory
    |> Array.to_list
    |> List.filter (fun file -> Filename.check_suffix file ".ml")
    |> List.map Filename.chop_extension
  in
  Sys.chdir test_directory;
  let only_if () =
    Sys.cygwin = false && Sys.win32 = false &&
    (* 4.02.3 prints file paths differently *)
    Scanf.sscanf Sys.ocaml_version "%u.%u"
      (fun major minor -> (major, minor) >= (4, 3))
  in
  let suite = Test.suite "ppx_expect" (
    List.map (fun test_case ->
      Test.test_direct test_case ~only_if (fun () ->
        run_test test_case;
        true
      )
    ) test_cases)
  in
  Test.run "ppx_expect" [suite]
