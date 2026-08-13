const toggle = document.querySelector('.nav-toggle');
const nav = document.querySelector('.main-nav');

if (toggle && nav) {
  toggle.addEventListener('click', () => {
    const open = nav.classList.toggle('open');
    toggle.setAttribute('aria-expanded', String(open));
  });
}

document.querySelectorAll('[data-year]').forEach((node) => {
  node.textContent = String(new Date().getFullYear());
});
