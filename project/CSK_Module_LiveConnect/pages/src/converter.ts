// Referenced in binding to disable Button when user lower as authorized client
export function getDisabled(value) {
  let disabled = true
  if (value.id >= 3){
    disabled = false
  }
  return disabled;
}

// create a sopasjs databinding
export function createDataBinding(
  property: string,
  topic: string,
  path: string,
  direction: string,
  updateOnResume?: boolean,
  autoCommit?: boolean,
  autoUpdate?: string,
  converter?: string
):any {
  const dataBinding = document.createElement('sjs-binding');
  
  //options - static post
  const optionsAttribute = document.createAttribute('options');
  optionsAttribute.value = JSON.stringify({
    method: 'POST',
    parseHeader: true
  });
  dataBinding.setAttributeNode(optionsAttribute);
  
  // property
  const propertyAttribute = document.createAttribute('property');
  propertyAttribute.value = property;
  dataBinding.setAttributeNode(propertyAttribute);
  
  // topic
  const topicAttribute = document.createAttribute('topic');
  topicAttribute.value = topic;
  dataBinding.setAttributeNode(topicAttribute);
  
  // path
  if(path && 0 !== path.length) {
    const pathAttribute = document.createAttribute('path');
    pathAttribute.value = path;
    dataBinding.setAttributeNode(pathAttribute);
  }
  
  // slot
  const slotAttribute = document.createAttribute('slot');
  slotAttribute.value = '__sjs-binding-slot__';
  dataBinding.setAttributeNode(slotAttribute);

  // direction
  const directionAttribute = document.createAttribute('direction');
  directionAttribute.value = direction;
  dataBinding.setAttributeNode(directionAttribute);

  //converter
  if (converter){
    if (direction === 'set') {
      const converterAttribute = document.createAttribute('post-get');
      converterAttribute.value = converter;
      dataBinding.setAttributeNode(converterAttribute);
    } else if (direction === 'get') {
      const converterAttribute = document.createAttribute('pre-set');
      converterAttribute.value = converter;
      dataBinding.setAttributeNode(converterAttribute);
    }
  }
  
  // auto update
  if (autoUpdate && autoUpdate.length !== 0) {
    const autoUpdateAttribute = document.createAttribute('auto-update');
    autoUpdateAttribute.value = autoUpdate;
    dataBinding.setAttributeNode(autoUpdateAttribute);
  }
  
  // update-on-resume
  if (updateOnResume && updateOnResume.length !== 0) {
    const updateOnResumeAttribute = document.createAttribute('update-on-resume');
    updateOnResumeAttribute.value = 'true';
    dataBinding.setAttributeNode(updateOnResumeAttribute);
  }

  // auto-commit
  if (autoCommit) {
    const autoCommitAttribute = document.createAttribute('auto-commit');
    autoCommitAttribute.value = 'true';
    dataBinding.setAttributeNode(autoCommitAttribute);
  }


  return dataBinding;
}

export function convertIpAddressArrayToIpAddressString(value) {
  if (value) {
    return value.join('.')
  }
  return '';
}

export function convertIpAddressStringToIpAddressArray(value) {
  if (value) { 
    return value.split('.').map(x=>+x)
  }
  return '';
}

export function enableEditIpSettings(userLevelId) {
  return userLevelId < 4;
}

export function showCloudSystem(userLevelId) {
  if(userLevelId >= 4) {
    return 1;
  }
  return 0;
}

export function updateValidateTokenButton(value) {
  var textfield = document.getElementById('softApprovalTokenTextField');
  var button = document.getElementById('validateTokenButton');

  if (true == button.disabled) {
    // Don't manipulate button's enabled state when the textfield is disabled
    if (false == textfield.disabled) {
      button.disabled = false;
    }

    var text = document.getElementById('softApprovalTokenTextField')
    text.value = ''
  }

  return value;
}
