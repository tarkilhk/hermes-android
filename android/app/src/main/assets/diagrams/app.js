(() => {
  'use strict';

  const MAX_SOURCE_LENGTH = 50_000;
  const diagram = document.getElementById('diagram');
  const status = document.getElementById('status');
  let renderSequence = 0;

  const blockedElements = 'script, foreignObject, iframe, object, embed, image, audio, video';
  const protectedConfig = [
    'secure',
    'securityLevel',
    'startOnLoad',
    'maxTextSize',
    'maxEdges',
    'suppressErrorRendering',
  ];

  function setTheme(dark) {
    document.documentElement.dataset.theme = dark ? 'dark' : 'light';
  }

  function clearPreview() {
    diagram.replaceChildren();
    diagram.hidden = true;
  }

  function showStatus(message) {
    clearPreview();
    status.textContent = String(message || 'The diagram could not be rendered.');
    status.hidden = false;
  }

  function friendlyRenderError(error) {
    const text = error instanceof Error ? error.message : String(error || '');
    const line = text.match(/(?:line|at line)\s+(\d+)/i)?.[1];
    return line
      ? `Mermaid could not parse the diagram near line ${line}. Check the syntax and try again.`
      : 'Mermaid could not parse this diagram. Check the syntax and try again.';
  }

  function validateSource(value) {
    if (typeof value !== 'string' || value.trim().length === 0) {
      throw new Error('EMPTY_SOURCE');
    }
    if (value.length > MAX_SOURCE_LENGTH) {
      throw new Error('SOURCE_TOO_LARGE');
    }
    if (/^\s*(?:\uFEFF)?---(?:\s|$)/.test(value) || /%%\s*\{/.test(value)) {
      throw new Error('CONFIG_OVERRIDE');
    }
  }

  function publicValidationError(error) {
    switch (error instanceof Error ? error.message : '') {
      case 'EMPTY_SOURCE':
        return 'There is no Mermaid diagram to preview.';
      case 'SOURCE_TOO_LARGE':
        return 'This Mermaid diagram is too large to preview.';
      case 'CONFIG_OVERRIDE':
        return 'Mermaid configuration directives are not allowed in previews.';
      default:
        return friendlyRenderError(error);
    }
  }

  function sanitizeSvg(svgMarkup) {
    const parsed = new DOMParser().parseFromString(svgMarkup, 'image/svg+xml');
    const svg = parsed.documentElement;
    if (svg.localName !== 'svg' || parsed.querySelector('parsererror')) {
      throw new Error('INVALID_SVG');
    }

    parsed.querySelectorAll(blockedElements).forEach((node) => node.remove());
    parsed.querySelectorAll('a').forEach((link) => link.replaceWith(...link.childNodes));

    parsed.querySelectorAll('*').forEach((node) => {
      for (const attribute of [...node.attributes]) {
        const name = attribute.name.toLowerCase();
        const isEventHandler = name.startsWith('on');
        const isLink = name === 'href' || name === 'xlink:href';
        if (isEventHandler || isLink) {
          node.removeAttribute(attribute.name);
        }
      }
    });

    svg.removeAttribute('width');
    svg.removeAttribute('height');
    svg.setAttribute('width', '100%');
    svg.setAttribute('height', 'auto');
    svg.setAttribute('preserveAspectRatio', 'xMidYMin meet');
    svg.setAttribute('role', 'img');
    svg.setAttribute('aria-label', 'Rendered Mermaid diagram');

    return document.importNode(svg, true);
  }

  async function render(source, dark, sequence) {
    setTheme(dark);
    status.hidden = true;

    try {
      validateSource(source);
      if (!window.mermaid || typeof window.mermaid.render !== 'function') {
        throw new Error('MERMAID_UNAVAILABLE');
      }

      window.mermaid.initialize({
        startOnLoad: false,
        securityLevel: 'strict',
        secure: protectedConfig,
        suppressErrorRendering: true,
        maxTextSize: MAX_SOURCE_LENGTH,
        maxEdges: 500,
        theme: dark ? 'dark' : 'default',
        fontFamily: 'system-ui, sans-serif',
        htmlLabels: false,
        flowchart: {
          htmlLabels: false,
          useMaxWidth: true,
        },
        sequence: {
          useMaxWidth: true,
          wrap: true,
        },
      });

      const rendered = await window.mermaid.render(`hermes-diagram-${sequence}`, source);
      const safeSvg = sanitizeSvg(rendered.svg);
      if (sequence !== renderSequence) return false;

      diagram.replaceChildren(safeSvg);
      diagram.hidden = false;
      return true;
    } catch (error) {
      if (sequence !== renderSequence) return false;
      showStatus(publicValidationError(error));
      return false;
    }
  }

  window.renderDiagram = (source, dark = false) => {
    renderSequence += 1;
    return render(source, Boolean(dark), renderSequence);
  };

  window.showDiagramError = (message) => {
    renderSequence += 1;
    showStatus(message);
  };

  document.addEventListener('click', (event) => {
    if (event.target.closest('a')) event.preventDefault();
  }, true);
  document.addEventListener('submit', (event) => event.preventDefault(), true);
  window.open = () => null;

  setTheme(false);
  clearPreview();
})();
