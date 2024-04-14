export const idlFactory = ({ IDL }) => {
  return IDL.Service({ 'run_tests' : IDL.Func([], [], []) });
};
export const init = ({ IDL }) => { return []; };
