local state = rawget(_G, "__requirex_test_counter") or 0
state = state + 1
rawset(_G, "__requirex_test_counter", state)

return {
    value = state,
}
