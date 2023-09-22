// Referenced in binding to disable Button when user lower as authorized client
export function getDisabled(value) {
  let disabled = true
  if (value.id >= 3){
    disabled = false
  }
  return disabled;
}