// Set darkmode
document.getElementById('mode').addEventListener('click', () => {

    document.body.classList.toggle('dark');
    localStorage.setItem('theme', document.body.classList.contains('dark') ? 'dark' : 'light');
  
});
  
// enforce local storage setting but also fallback to user-agent preferences, defaulting to dark
if (localStorage.getItem('theme') !== 'light' && !(!localStorage.getItem('theme') && window.matchMedia("(prefers-color-scheme: light)").matches)) {

  document.body.classList.add('dark');

}
